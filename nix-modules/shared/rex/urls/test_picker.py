import unittest

from picker import extract


class ExtractionTests(unittest.TestCase):
    def test_url_query_and_trailing_punctuation(self):
        self.assertEqual(extract("See (https://example.com/path?q=1&x=2)."),
                         ["https://example.com/path?q=1&x=2"])

    def test_terminal_url_forms(self):
        self.assertEqual(extract("www.example.com 10.0.0.1:8080/api "
                                 "git@github.com:owner/repo.git 'owner/repo'"), [
            "http://www.example.com", "http://10.0.0.1:8080/api",
            "https://github.com/owner/repo.git", "https://github.com/owner/repo",
        ])

    def test_duplicates_and_empty_content(self):
        self.assertEqual(extract("no links here"), [])
        self.assertEqual(extract("https://example.com https://example.com"),
                         ["https://example.com"])

    def test_shell_metacharacters_are_url_text(self):
        self.assertEqual(extract("https://example.com/?x=1&y=2;whoami"),
                         ["https://example.com/?x=1&y=2;whoami"])


if __name__ == "__main__":
    unittest.main()
