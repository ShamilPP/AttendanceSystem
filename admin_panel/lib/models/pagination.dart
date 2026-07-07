import '../utils/json_utils.dart';

/// `pagination: { page, limit, total, totalPages }` on list responses.
class Pagination {
  const Pagination({
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasPrev => page > 1;
  bool get hasNext => page < totalPages;

  factory Pagination.fromJson(dynamic json) {
    final map = jsonMap(json);
    return Pagination(
      page: jsonInt(map['page'], 1),
      limit: jsonInt(map['limit'], 20),
      total: jsonInt(map['total']),
      totalPages: jsonInt(map['totalPages'], 1),
    );
  }
}
