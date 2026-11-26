import unittest

from picker import extract_urls


class ExtractionTests(unittest.TestCase):
    def test_url_query_and_trailing_punctuation(self):
        self.assertEqual(extract_urls("See (https://example.com/path?q=1&x=2)."),
                         ["https://example.com/path?q=1&x=2"])

    def test_terminal_url_forms(self):
        self.assertEqual(extract_urls("www.example.com 10.0.0.1:8080/api "
                                 "git@github.com:owner/repo.git 'owner/repo'"), [
            "https://github.com/owner/repo",
            "https://github.com/owner/repo.git", 
            "http://10.0.0.1:8080/api",
            "http://www.example.com",
        ])

    def test_duplicates_and_empty_content(self):
        self.assertEqual(extract_urls("no links here"), [])
        self.assertEqual(extract_urls("https://example.com https://example.com"),
                         ["https://example.com"])

    def test_shell_metacharacters_are_url_text(self):
        self.assertEqual(extract_urls("https://example.com/?x=1&y=2;whoami"),
                         ["https://example.com/?x=1&y=2;whoami"])


if __name__ == "__main__":
    unittest.main()
