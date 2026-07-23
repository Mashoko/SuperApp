const faqSeedData = require('../scripts/faq-seed-data');

describe('faqSeedData', () => {
  test('has 7 categories with unique titles', () => {
    expect(faqSeedData).toHaveLength(7);
    const titles = faqSeedData.map((c) => c.title);
    expect(new Set(titles).size).toBe(7);
  });

  test('every category has at least one item with a non-empty question and answer', () => {
    for (const category of faqSeedData) {
      expect(category.items.length).toBeGreaterThan(0);
      for (const item of category.items) {
        expect(item.question.length).toBeGreaterThan(0);
        expect(item.answer.length).toBeGreaterThan(0);
      }
    }
  });

  test('includes the known Payments and General categories', () => {
    const titles = faqSeedData.map((c) => c.title);
    expect(titles).toContain('Payments');
    expect(titles).toContain('General');
  });
});
