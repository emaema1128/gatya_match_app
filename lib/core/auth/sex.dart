/// bloom's `sex` param for `registUser`. Values inferred from
/// `Class_UserApi.php`'s `getUserList`, which does a strict `===` string
/// comparison against `'0'` — bloom expects this as a string, not an int.
/// 0=male/1=female is inferred from the same comparison and needs to be
/// confirmed against a real registration once this ships.
enum Sex {
  male('0'),
  female('1');

  const Sex(this.apiValue);

  final String apiValue;
}
