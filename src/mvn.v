module mvn

pub struct MavenObj {
	group       string
	artifact_id string
	version     string
}

pub enum MavenObjType {
	jar
	pom
}

pub fn (mvn_obj MavenObj) to_name(typ MavenObjType) string {
	return match typ {
		.jar {
			'${mvn_obj.artifact_id}-${mvn_obj.version}.jar'
		}
		.pom {
			'${mvn_obj.artifact_id}-${mvn_obj.version}.pom'
		}
	}
}

pub fn (mvn_obj MavenObj) as_url(typ MavenObjType) string {
	format_as_url_part := mvn_obj.group.replace('.', '/') + '/' + mvn_obj.artifact_id + '/' +
		mvn_obj.version + '/'
	return match typ {
		.jar {
			'${format_as_url_part}${mvn_obj.to_name(.jar)}'
		}
		.pom {
			'${format_as_url_part}${mvn_obj.to_name(.pom)}'
		}
	}
}
