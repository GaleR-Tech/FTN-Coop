extends RefCounted

const DOWNLOAD_URL := "https://github.com/GaleR-Tech/FTN-Coop/releases"

static func safe_version(value: Variant) -> String:
	if not value is String or value.length()>40: return ""
	var matched := RegEx.create_from_string("^[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}(-[a-z0-9.]{1,16})?$").search(value)
	return value if matched!=null and matched.get_string()==value else ""
