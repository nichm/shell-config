// =============================================================================
// Prettier Configuration - Optimized for AI Code Generation
// =============================================================================
// Optimized settings for AI-generated code:
// - Consistent formatting across all file types
// - Wider print width for better readability
// - Single quotes (matches shell script style)
// - Trailing commas for easier diffs
// =============================================================================

module.exports = {
  // General formatting (optimized for AI code)
  semi: true, // Semicolons for clarity
  trailingComma: 'es5', // Trailing commas for easier diffs
  singleQuote: true, // Single quotes (matches shell script style)
  printWidth: 100, // Wider for better readability
  tabWidth: 2, // 2 spaces (standard)
  useTabs: false, // Spaces, not tabs
  arrowParens: 'always', // Always include parens for clarity
  bracketSpacing: true, // Spaces in object literals
  endOfLine: 'lf', // Unix line endings (consistent)
  quoteProps: 'as-needed', // Only quote when needed

  // YAML specific settings (GitHub Actions, config files)
  overrides: [
    {
      files: ['*.yml', '*.yaml'],
      options: {
        printWidth: 120, // Wider for YAML (long keys/values)
        tabWidth: 2,
        useTabs: false,
        singleQuote: false, // Use double quotes for YAML (standard)
        proseWrap: 'preserve', // Preserve line breaks in prose
        bracketSpacing: true,
      },
    },
    {
      files: ['*.md'],
      options: {
        printWidth: 80, // Standard for markdown
        proseWrap: 'always', // Wrap prose lines
        tabWidth: 2,
        printWidth: 80,
      },
    },
    {
      files: ['*.json'],
      options: {
        printWidth: 100,
        tabWidth: 2,
        trailingComma: 'none', // No trailing commas in JSON
        singleQuote: false, // Double quotes required in JSON
      },
    },
    {
      files: ['*.js', '*.jsx', '*.ts', '*.tsx'],
      options: {
        printWidth: 100, // Consistent with general settings
        tabWidth: 2,
        semi: true,
        singleQuote: true,
        trailingComma: 'es5',
      },
    },
  ],
};
