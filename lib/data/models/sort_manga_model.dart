// lib/data/models/sort_manga_model.dart
class SortManga {
  String? title;
  String? status;
  String? safety;
  String? demographic;
  List<String>? includedTags;
  List<String>? excludedTags;
  List<String>? languages;
  String? sortBy;

  // Constructor
  SortManga({
    this.title,
    this.status,
    this.safety,
    this.demographic,
    this.includedTags,
    this.excludedTags,
    this.languages,
    this.sortBy,
  });

  // Hàm xử lý các thuộc tính null
  void handleNullValues() {
    title ??= '';
    status ??= 'Tất cả';
    safety ??= 'Tất cả';
    demographic ??= 'Tất cả';
    includedTags ??= [];
    excludedTags ??= [];
    languages ??= [];
    sortBy ??= 'Mới cập nhật';
  }

  // Hàm chuyển đổi thành params
  Map<String, dynamic> toParams() {
    handleNullValues();
    final params = <String, dynamic>{};

    if (title!.isNotEmpty) params['title'] = title;
    if (status != 'Tất cả') params['status[]'] = [status!.toLowerCase()];
    if (safety != 'Tất cả') params['contentRating[]'] = [safety!.toLowerCase()];
    if (demographic != 'Tất cả')
      params['publicationDemographic[]'] = [demographic!.toLowerCase()];
    if (includedTags!.isNotEmpty) params['includedTags[]'] = includedTags;
    if (excludedTags!.isNotEmpty) params['excludedTags[]'] = excludedTags;
    if (languages!.isNotEmpty)
      params['availableTranslatedLanguage[]'] = languages;
    params['order[updatedAt]'] = sortBy == 'Mới cập nhật' ? 'desc' : 'asc';

    return params;
  }
}
