# web2offline

A robust, self-contained Bash script that downloads any web URL and saves it as a single, offline file (HTML or Markdown). The output preserves the original page's visual layout and styling without relying on external network requests or JavaScript.

## Features

- **🌐 Completely Offline**: All images are converted to Base64 data URIs, ensuring the file renders without network access
- **🎨 Visual Fidelity**: Original page layout, colors, typography, and structure are preserved by inlining CSS
- **🔒 Security First**: All JavaScript is stripped (`<script>` tags, inline handlers, `javascript:` protocols)
- **📄 Dual Format**: Save as HTML (default) or convert to Markdown
- **🔗 Source Attribution**: Elegant fixed-position link to the original URL at the top-right corner
- **📦 Zero Dependencies**: Uses only standard Linux CLI tools (`curl`, `grep`, `sed`, `awk`, `base64`)
- **⚡ Smart Naming**: Automatic filename generation: `[Page_Title]_[YYYYMMDD_HHMMSS].[extension]`

## Requirements

The script relies on standard tools pre-installed on most Linux distributions:

- `curl` - For downloading web content
- `grep`, `sed`, `awk` - For text processing
- `base64` - For encoding images
- `bash` (v4.0+) - Shell interpreter

No Node.js, Python, or third-party packages required.

## Installation

### System-wide Installation (requires sudo)

```bash
git clone https://github.com/yourusername/web2offline.git
cd web2offline
sudo make install
```

This installs the script to `/usr/local/bin/web2offline`.

### Local Installation (no sudo required)

```bash
git clone https://github.com/yourusername/web2offline.git
cd web2offline
make install-local
```

This installs the script to `~/.local/bin/web2offline`. Ensure `~/.local/bin` is in your `PATH`.

### Verify Installation

```bash
web2offline --version
web2offline --help
```

## Usage

### Basic Usage

```bash
# Save as HTML (default)
web2offline https://example.com

# Save as Markdown
web2offline --markdown https://example.com
```

### Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | `-h` | Display help menu and usage examples |
| `--html` | `-html` | Save as offline HTML file (default) |
| `--markdown` | `-md` | Convert and save as Markdown file |
| `--verbose` | `-v` | Enable verbose/debug mode |
| `--version` | `-V` | Show version information |

### Examples

```bash
# Download a webpage as HTML
web2offline https://www.wikipedia.org

# Download and convert to Markdown
web2offline --markdown https://news.ycombinator.com

# Verbose mode for debugging
web2offline --verbose https://example.com

# Custom output directory
OUTPUT_DIR=~/downloads web2offline https://example.com

# Custom timeout (in seconds)
TIMEOUT=60 web2offline https://slow-site.com
```

### Output Filename

Files are saved with the naming convention:

```
[Sanitized_Page_Title]_[YYYYMMDD_HHMMSS].[extension]
```

Examples:
- `Example_Domain_20250115_143022.html`
- `Hacker_News_20250115_143055.md`

Titles are automatically sanitized to remove characters invalid in filenames.

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make install` | Install to `/usr/local/bin` (requires sudo) |
| `make install-local` | Install to `~/.local/bin` (no sudo) |
| `make uninstall` | Remove from system |
| `make test` | Run all automated tests |
| `make test-html` | Test HTML output only |
| `make test-markdown` | Test Markdown output only |
| `make test-help` | Test help menu display |
| `make test-offline` | Syntax validation (no network) |
| `make debug URL=<url>` | Debug execution (HTML mode) |
| `make debug-md URL=<url>` | Debug execution (Markdown mode) |
| `make lint` | Run ShellCheck for best practices |
| `make validate` | Run all validations |
| `make clean` | Remove generated test files |
| `make help` | Display available targets |

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
make test-html
make test-markdown
make test-offline

# Lint the script
make lint

# Debug a specific URL
make debug URL=https://example.com
```

## How It Works

### HTML Mode

1. **Download**: Fetches the HTML content using `curl`
2. **Extract Title**: Parses the `<title>` tag for filename generation
3. **Inline CSS**: Downloads and embeds external stylesheets as `<style>` blocks
4. **Inline Images**: Converts all image sources to Base64 data URIs
5. **Strip JavaScript**: Removes `<script>` tags, `onclick` handlers, and `javascript:` URLs
6. **Inject Source Link**: Adds a styled link to the original URL at the top-right
7. **Save**: Writes the self-contained HTML file

### Markdown Mode

1. **Download**: Fetches the HTML content
2. **Extract Title**: Parses the `<title>` tag
3. **Convert**: Transforms HTML elements to Markdown equivalents:
   - Headings (`<h1>` → `#`, `<h2>` → `##`, etc.)
   - Links (`<a href>` → `[text](url)`)
   - Images (`<img>` → `![alt](src)`)
   - Lists, blockquotes, code blocks, etc.
4. **Inline Images**: Converts image URLs to Base64 data URIs
5. **Add Source Link**: Prepends a link to the original URL at the top
6. **Save**: Writes the Markdown file

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OUTPUT_DIR` | Current directory | Custom output directory for saved files |
| `TIMEOUT` | `30` | Network request timeout in seconds |
| `CURL_OPTS` | (empty) | Additional curl options |

### Example

```bash
# Save to custom directory with longer timeout
OUTPUT_DIR=~/archives TIMEOUT=60 web2offline https://example.com
```

## Security Considerations

- ✅ **JavaScript Stripped**: All `<script>` tags and inline event handlers are removed
- ✅ **No External Requests**: Saved files contain no references to external resources
- ✅ **Safe Filenames**: Page titles are sanitized to prevent path traversal or injection
- ⚠️ **HTTPS Recommended**: Always use HTTPS URLs to ensure secure downloads
- ⚠️ **Trust Sources**: Only download from trusted websites

## Limitations

- **Dynamic Content**: Pages that rely heavily on JavaScript for rendering may not display correctly (by design, as JS is stripped)
- **Complex CSS**: Some advanced CSS features (e.g., CSS variables, complex selectors) may not render identically offline
- **Large Images**: Pages with many high-resolution images will result in large file sizes due to Base64 encoding (~33% overhead)
- **Interactive Elements**: Forms, buttons with JS handlers, and dynamic content will be non-functional

## Troubleshooting

### Common Issues

**Issue**: Script not found after installation  
**Solution**: Ensure the installation directory is in your `PATH`:
```bash
export PATH=$PATH:/usr/local/bin  # or ~/.local/bin
```

**Issue**: Images not displaying  
**Solution**: Check if the image URLs are accessible. Some sites block automated downloads. Try increasing the timeout:
```bash
TIMEOUT=60 web2offline https://example.com
```

**Issue**: CSS not rendering correctly  
**Solution**: Some sites use CSS-in-JS or dynamic stylesheets. These cannot be inlined. The script handles standard `<link rel="stylesheet">` tags.

**Issue**: Permission denied during install  
**Solution**: Use `sudo` for system-wide install or use local install:
```bash
sudo make install
# or
make install-local
```

### Debug Mode

Enable verbose output to trace execution:

```bash
web2offline --verbose https://example.com
# or
set -x && web2offline https://example.com
```

Or use the Makefile:

```bash
make debug URL=https://example.com
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create a branch**: `git checkout -b feature/your-feature`
3. **Make changes** following ShellCheck best practices
4. **Test**: Run `make validate` to ensure all tests pass
5. **Commit**: Use descriptive commit messages
6. **Push** and open a Pull Request

### Code Style

- Follow [ShellCheck](https://www.shellcheck.net/) recommendations
- Use meaningful variable names
- Comment complex logic
- Keep functions small and focused

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with standard GNU/Linux utilities
- Inspired by tools like `monolith`, `wget -p`, and `single-file`
- Designed for simplicity, portability, and security

## Support

For issues, questions, or feature requests, please open an issue on the [GitHub repository](https://github.com/yourusername/web2offline/issues).

---

**Made with ❤️ using Bash**
