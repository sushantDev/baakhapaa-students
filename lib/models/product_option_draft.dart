class ProductOptionDraft {
  String name;
  List<String> values;

  ProductOptionDraft({
    this.name = '',
    List<String>? values,
  }) : values = values ?? [];
}
