class_name Num
extends RefCounted
## Number formatting for the "numbers go up" UI: 950, 9,500, 95.0K, 9.50M, 9.50B.


static func short(n: float) -> String:
	var a := absf(n)
	if a < 10000.0:
		return _commas(roundi(n))
	for unit in [[1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]:
		if a >= unit[0]:
			var v: float = n / unit[0]
			return ("%.2f" if absf(v) < 10.0 else ("%.1f" if absf(v) < 100.0 else "%.0f")) % v + unit[1]
	return str(roundi(n))


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
