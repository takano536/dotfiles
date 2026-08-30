# Coding Guidelines

- When writing prose intended for humans, including comments, commit messages, and responses, use as few words as practical. Choose words carefully and stay focused.

- Avoid superlatives, praise, and unnecessary agreement. Be factual and direct.

- Avoid magic numbers and magic strings. Extract recurring or meaningful values into descriptive constants or enums. Keep self-explanatory one-off values inline when extracting them would only add clutter. Use named constants for values defined by a specification.

- Reduce indentation. Avoid deeply nested control flow. Prefer early returns and continues where they make the code clearer.

- Give readers room to breathe. Use blank lines between logical blocks of code.

- Add concise comments that explain what a logical block does or why it exists when they improve readability. Do not comment every line or merely restate individual statements. Keep comments brief and focused; avoid verbose explanations and implementation narration.

- Program at the appropriate level of abstraction. Encapsulate low-level mechanisms behind dedicated abstractions and expose APIs expressed in domain concepts rather than raw implementation details.

- Do not modify code unrelated to the requested feature or fix. Do not add comments or perform cleanup in unrelated code. Minimize the number of changed lines consistent with a correct implementation.

- Respect architectural and abstraction boundaries. Do not bypass layers to directly access lower-level implementation details. Route interactions through the appropriate intermediate abstraction.

- When writing a commit message, separate the subject from the body with a blank line. Keep the subject concise, use the imperative mood, capitalize it, and do not end it with a period. Use the body to explain what and why rather than how.

- For bug fixes, establish the failure before implementing the fix when practical. Prefer a regression test that fails before the fix and passes afterward. When a test is not practical, establish equivalent reproducible evidence before and after the change.