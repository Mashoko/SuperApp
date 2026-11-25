const { canonicalUsername } = require('../lib/phone');

describe('canonicalUsername', () => {
  test.each([
    ['263770000000', '+263770000000'],
    ['+263770000000', '+263770000000'],
    ['  +263770000000  ', '+263770000000'],
    ['263 77 000 0000', '+263770000000'],
    ['+263-77-000-0000', '+263770000000'],
    ['(263) 770-000-000', '+263770000000'],
    ['0770000000', '+0770000000'],
  ])('phone %p -> %p', (input, expected) => {
    expect(canonicalUsername(input)).toBe(expected);
  });

  test.each([
    ['alice', 'alice'],
    ['  alice  ', 'alice'],
    ['legacyUser', 'legacyUser'],
    ['bob 2', 'bob 2'],
    ['+', '+'],
    ['++263770000000', '++263770000000'],
    ['263+770000000', '263+770000000'],
    ['', ''],
  ])('non-phone %p is returned trimmed and unchanged', (input, expected) => {
    expect(canonicalUsername(input)).toBe(expected);
  });
});
