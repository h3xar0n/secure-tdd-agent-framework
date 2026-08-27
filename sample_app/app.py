"""Sample application demonstrating secure endpoint implementation."""

import os
import sqlite3
from flask import Flask, request, jsonify, redirect
from sample_app.utils.security import resolve_safe_path, safe_redirect, validate_username

app = Flask(__name__)
app.config['SECRET_KEY'] = os.getenv('APP_SECRET_KEY', 'default-dev-key')

UPLOAD_DIRECTORY = os.getenv('UPLOAD_DIR', '/tmp/sample_uploads')
ALLOWED_REDIRECT_HOSTS = {'localhost', '127.0.0.1', 'example.com'}

# Ensure sample upload directory exists
os.makedirs(UPLOAD_DIRECTORY, exist_ok=True)


def init_db():
    conn = sqlite3.connect(':memory:')
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, role TEXT, email TEXT)')
    cursor.execute("INSERT INTO users (username, role, email) VALUES ('alice', 'admin', 'alice@example.com')")
    cursor.execute("INSERT INTO users (username, role, email) VALUES ('bob', 'user', 'bob@example.com')")
    conn.commit()
    return conn

# Shared in-memory DB for demonstration
DB_CONN = init_db()


@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200


@app.route('/user')
def get_user():
    username = request.args.get('username')
    try:
        clean_user = validate_username(username)
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    cursor = DB_CONN.cursor()
    # Parameterized query (Defensive Developer Pillar 3)
    cursor.execute("SELECT username, role, email FROM users WHERE username = ?", (clean_user,))
    user = cursor.fetchone()
    if not user:
        return jsonify({"error": "User not found"}), 404

    # Return least-privilege payload (Pillar 3)
    return jsonify({"username": user[0], "role": user[1], "email": user[2]}), 200


@app.route('/read_file')
def read_file():
    filename = request.args.get('file')
    if not filename:
        return jsonify({"error": "File parameter required"}), 400

    try:
        safe_path = resolve_safe_path(UPLOAD_DIRECTORY, filename)
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    if not os.path.exists(safe_path):
        return jsonify({"error": "File not found"}), 404

    with open(safe_path, 'r', encoding='utf-8') as f:
        content = f.read()

    return jsonify({"filename": os.path.basename(safe_path), "content": content}), 200


@app.route('/redirect')
def handle_redirect():
    target = request.args.get('url')
    if not target:
        return jsonify({"error": "URL parameter required"}), 400

    try:
        validated_url = safe_redirect(target, ALLOWED_REDIRECT_HOSTS)
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    return redirect(validated_url)


if __name__ == '__main__':
    app.run(port=8080, debug=False)
