class ShortTopic {
  final int? id;
  final String? title;
  // final int time_limit;
  // final int likes;
  // final int coin;
  // final String description;

  ShortTopic({
    this.id,
    this.title,
    // this.time_limit,
    // this.likes,
    // this.coin,
    // this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }
}
