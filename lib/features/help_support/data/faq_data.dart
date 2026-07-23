class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
        json['question'] as String,
        json['answer'] as String,
      );

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

class FaqCategory {
  final String title;
  final List<FaqItem> items;
  const FaqCategory({required this.title, required this.items});

  factory FaqCategory.fromJson(Map<String, dynamic> json) => FaqCategory(
        title: json['title'] as String,
        items: (json['items'] as List)
            .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'items': items.map((e) => e.toJson()).toList(),
      };
}
