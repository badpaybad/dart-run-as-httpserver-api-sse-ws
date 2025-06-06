abstract class IEntity<T> {
  @override
  String toString();

  Map<String, dynamic> toMap();

  // factory T.fromMap(Map<String, dynamic> map) ;
  //  Map<String, dynamic> toJson();

  // factory T.fromJson(Map<String, dynamic> map) ;
}
