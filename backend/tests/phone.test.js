const { canonicalUsername } = require('../lib/phone');

describe('canonicalUsername', () => {
  test.each([
    ['263771234567', '+263771234567'],
    ['+263771234567', '+263771234567'],
    ['  +263771234567  ', '+263771234567'],
    ['263 77 123 4567', '+263771234567'],
    ['+263-77-123-4567', '+263771234567'],
    ['(263) 771-234-567', '+263771234567'],
    ['0771234567', '+0771234567'],
  ])('phone %p -> %p', (input, expected) => {
    expect(canonicalUsername(input)).toBe(expected);
  });

  test.each([
    ['alice', 'alice'],
    ['  alice  ', 'alice'],
    ['legacyUser', 'legacyUser'],
    ['bob 2', 'bob 2'],
    ['+', '+'],
    ['++263771234567', '++263771234567'],
    ['263+771234567', '263+771234567'],
    ['', ''],
  ])('non-phone %p is returned trimmed and unchanged', (input, expected) => {
    expect(canonicalUsername(input)).toBe(expected);
  });
});
