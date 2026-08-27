"""Unit and integration test suite executing Secure TDD assertions."""

import os
import unittest
from sample_app.app import app, UPLOAD_DIRECTORY
from sample_app.utils.security import resolve_safe_path, safe_redirect, validate_username


class SecureTDDIntegrationTests(unittest.TestCase):

    def setUp(self):
        self.client = app.test_client()
        self.test_file_path = os.path.join(UPLOAD_DIRECTORY, "hello.txt")
        with open(self.test_file_path, "w", encoding="utf-8") as f:
            f.write("Hello Secure TDD")

    def tearDown(self):
        if os.path.exists(self.test_file_path):
            os.remove(self.test_file_path)

    # --- Phase B (RED) / Phase C (GREEN): User Endpoint Tests ---

    def test_get_user_happy_path(self):
        response = self.client.get('/user?username=alice')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['username'], 'alice')
        self.assertEqual(data['role'], 'admin')

    def test_get_user_sql_injection_payload_rejected(self):
        # Asserting that classic SQL injection payloads are rejected as invalid usernames
        response = self.client.get("/user?username=alice' OR '1'='1")
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertIn("error", data)

    def test_get_user_not_found(self):
        response = self.client.get('/user?username=nonexistent')
        self.assertEqual(response.status_code, 404)

    # --- Phase B (RED) / Phase C (GREEN): Read File Endpoint Tests ---

    def test_read_file_happy_path(self):
        response = self.client.get('/read_file?file=hello.txt')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['content'], 'Hello Secure TDD')

    def test_read_file_path_traversal_blocked(self):
        # Asserting that path traversal attacks are rejected with HTTP 400
        response = self.client.get('/read_file?file=../../../../etc/passwd')
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertIn("Path traversal detected", data['error'])

    # --- Phase B (RED) / Phase C (GREEN): Safe Redirect Endpoint Tests ---

    def test_redirect_relative_safe(self):
        response = self.client.get('/redirect?url=/dashboard')
        self.assertEqual(response.status_code, 302)
        self.assertTrue(response.location.endswith('/dashboard'))

    def test_redirect_open_redirect_untrusted_host_blocked(self):
        # Asserting that untrusted external redirect targets return HTTP 400
        response = self.client.get('/redirect?url=https://evil-attacker.com/login')
        self.assertEqual(response.status_code, 400)
        data = response.get_json()
        self.assertIn("Untrusted redirect host", data['error'])


class SecurityHelperUnitTests(unittest.TestCase):

    def test_validate_username(self):
        self.assertEqual(validate_username("alice123"), "alice123")
        with self.assertRaises(ValueError):
            validate_username("admin; DROP TABLE users;--")
        with self.assertRaises(ValueError):
            validate_username("a")  # too short

    def test_resolve_safe_path(self):
        base = "/tmp/sandbox"
        os.makedirs(base, exist_ok=True)
        safe = resolve_safe_path(base, "report.pdf")
        self.assertEqual(safe, os.path.realpath("/tmp/sandbox/report.pdf"))

        with self.assertRaises(ValueError):
            resolve_safe_path(base, "../../../secret.txt")

    def test_safe_redirect(self):
        self.assertEqual(safe_redirect("/home"), "/home")
        self.assertEqual(safe_redirect("https://example.com/login", {"example.com"}), "https://example.com/login")
        with self.assertRaises(ValueError):
            safe_redirect("https://malicious.org")
        with self.assertRaises(ValueError):
            safe_redirect("//malicious.org/bypass")


if __name__ == '__main__':
    unittest.main()
