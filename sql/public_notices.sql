--
-- address
--
CREATE TEMPORARY TABLE tmp_address (
  notice_uid TEXT NOT NULL,
  name TEXT NOT NULL,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  address TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  UNIQUE (name)
);
INSERT OR IGNORE INTO tmp_address (
  notice_uid,
  name,
  lat,
  lon,
  address,
  postal_code
)
WITH cte AS (
  SELECT
    n.noticeId,
    trim(json_each.value->>'$.fullAddress') name
  FROM
    data.notice n,
    json_each(n.addressList)
)
SELECT
  n.noticeId,
  CASE
    WHEN like('% Toronto Ontario', cte.name) THEN trim(substr(cte.name, 1, length(cte.name) - length(' Toronto Ontario')))
    WHEN like('% Toronto ON', cte.name) THEN trim(substr(cte.name, 1, length(cte.name) - length(' Toronto ON')))
    ELSE cte.name
  END,
  json_each.value->>'$.latitudeCoordinate',
  json_each.value->>'$.longitudeCoordinate',
  trim(coalesce(json_each.value->>'$.streetAddress', '')),
  trim(coalesce(json_each.value->>'$.postalCode', ''))
FROM
  data.notice n,
  json_each(n.addressList)
JOIN
  cte
ON
  n.noticeId = cte.noticeId
;

DROP TABLE IF EXISTS address;
CREATE TABLE address (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  address TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  geometry AS (
    json_object(
      'type', 'Point',
      'coordinates', json(json_array(lon, lat))
    )
  ),
  UNIQUE (name)
);
INSERT INTO address (
  name,
  lat,
  lon,
  address,
  postal_code
)
SELECT DISTINCT
  name,
  lat,
  lon,
  address,
  postal_code
FROM
  tmp_address
;
DROP TABLE IF EXISTS address_fts;
CREATE VIRTUAL TABLE address_fts USING fts5 (name, content="address");
INSERT INTO address_fts (
  rowid,
  name
)
SELECT
  rowid,
  name
FROM 
  address
;


--
-- contact
--
CREATE TEMPORARY TABLE tmp_contact (
  notice_uid TEXT NOT NULL,
  name,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT NOT NULL,
  location TEXT NOT NULL
);
INSERT INTO tmp_contact (
  notice_uid,
  name,
  email,
  phone,
  address,
  location
)
WITH cte AS (
  SELECT
    n.noticeId,
    trim(replace(coalesce(n.contact->>'$.streetAddress', ''), '  ', ' ')) address
  FROM
    data.notice n
)
SELECT
  n.noticeId,
  trim(n.contact->>'$.contactName'),
  trim(lower(coalesce(n.contact->>'$.emailAddress', ''))),
  trim(coalesce(n.contact->>'$.phone', '')),
  CASE
    WHEN (
      like('100 Queen %', cte.address)
      OR cte.address IN ('100 Queen', '100 Queen` Street West', '100 100 Queen Street West')
    ) THEN '100 Queen Street West'
    WHEN (
      like('55 John Street%', cte.address)
    ) THEN '55 John Street'
    ELSE cte.address
  END,
  trim(coalesce(n.contact->>'$.locationName', ''))
FROM
  data.notice n
JOIN
  cte
ON
  n.noticeId = cte.noticeId
WHERE
  n.contact IS NOT NULL
;
DROP TABLE IF EXISTS contact;
CREATE TABLE contact (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  address TEXT NOT NULL,
  location TEXT NOT NULL,
  UNIQUE (name, email, phone, address, location)
);
INSERT INTO contact (
  name,
  email,
  phone,
  address,
  location
)
SELECT DISTINCT
  name,
  email,
  phone,
  address,
  location
FROM
  tmp_contact
;
DROP TABLE IF EXISTS contact_fts;
CREATE VIRTUAL TABLE contact_fts USING fts5 (name, email, content="contact");
INSERT INTO contact_fts (
  rowid,
  name,
  email
)
SELECT
  rowid,
  name,
  email
FROM 
  contact
;

--
-- notice
--
DROP TABLE IF EXISTS main.notice;
CREATE TABLE notice (
  uid TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  decision_body TEXT NOT NULL,
  date_utc TEXT NOT NULL,
  description_html TEXT NOT NULL,
  signed_by TEXT NOT NULL

);
INSERT INTO notice (
  uid,
  title,
  subtitle,
  decision_body,
  date_utc,
  description_html,
  signed_by
)
SELECT
  trim(n.noticeId),
  trim(n.title),
  trim(coalesce(n.subheading, '')),
  trim(coalesce(n.decisionBody, '')),
  datetime(n.noticeDate / 1000, 'unixepoch'),
  trim(n.noticeDescription),
  trim(coalesce(n.signedBy, ''))
FROM
  data.notice n
;
CREATE INDEX idx_notice_date_utc ON notice (date_utc);
DROP TABLE IF EXISTS notice_fts;
CREATE VIRTUAL TABLE notice_fts USING fts5 (title, subtitle, description_html, content="notice");
INSERT INTO notice_fts (
  rowid,
  title,
  subtitle,
  description_html
)
SELECT
  rowid,
  title,
  subtitle,
  description_html
FROM 
  notice
;

--
-- notice_contact
--
DROP TABLE IF EXISTS notice_contact;
CREATE TABLE notice_contact (
  notice_uid TEXT NOT NULL,
  contact_id INTEGER NOT NULL,
  FOREIGN KEY (notice_uid) REFERENCES notice (uid),
  FOREIGN KEY (contact_id) REFERENCES contact (id)
);
INSERT INTO notice_contact (
  notice_uid,
  contact_id
)
SELECT DISTINCT
  notice_uid,
  contact.id
FROM
  tmp_contact
JOIN
  contact
ON
  tmp_contact.name = contact.name
  AND tmp_contact.email = contact.email
  AND tmp_contact.phone = contact.phone
  AND tmp_contact.address = contact.address
  AND tmp_contact.location = contact.location
;

--
-- topic
--
DROP TABLE IF EXISTS topic;
CREATE TABLE topic (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);
INSERT OR IGNORE INTO topic (name)
SELECT DISTINCT json_each.value FROM data.notice n, json_each(n.topics)
;

--
-- notice_address
--
DROP TABLE IF EXISTS notice_address;
CREATE TABLE notice_address (
  notice_uid TEXT NOT NULL,
  address_id INTEGER NOT NULL,
  PRIMARY KEY (notice_uid, address_id),
  FOREIGN KEY (notice_uid) REFERENCES notice (uid),
  FOREIGN KEY (address_id) REFERENCES address (id)
);
INSERT OR IGNORE INTO notice_address (
  notice_uid,
  address_id
)
SELECT
  notice_uid,
  address.id
FROM
  tmp_address
JOIN
  address
ON
  tmp_address.name = address.name
;
CREATE INDEX idx_notice_address_notice_uid ON notice_address (notice_uid);
CREATE INDEX idx_notice_address_address_id ON notice_address (address_id);

DROP TABLE IF EXISTS notice_event;
CREATE TABLE notice_event (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  notice_uid TEXT NOT NULL,
  datetime_utc NOT NULL,
  location TEXT NOT NULL,
  address TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  FOREIGN KEY (notice_uid) REFERENCES notice (uid)
);
INSERT INTO notice_event (
  notice_uid,
  datetime_utc,
  location,
  address,
  postal_code
)
SELECT
  n.noticeId,
  datetime(json_each.value->>'$.startDateTime' / 1000, 'unixepoch'),
  trim(coalesce(json_each.value->>'$.locationName', '')),
  trim(coalesce(json_each.value->>'$.streetAddress', '')),
  trim(coalesce(json_each.value->>'$.postalCode', ''))
FROM
  data.notice n,
  json_each(n.json, '$.eventList')
;
CREATE INDEX idx_notice_event_notice_uid ON notice_event (notice_uid);

DROP TABLE IF EXISTS notice_topic;
CREATE TABLE notice_topic (
  notice_uid TEXT NOT NULL,
  topic_id INTEGER NOT NULL,
  PRIMARY KEY (notice_uid, topic_id)
  FOREIGN KEY (notice_uid) REFERENCES notice (uid),
  FOREIGN KEY (topic_id) REFERENCES topic (id)
);
INSERT INTO notice_topic (
  notice_uid,
   topic_id 
)
WITH cte AS (
  SELECT
    n.noticeId notice_id,
    json_each.value topic_name
  FROM
    data.notice n,
    json_each(n.json, '$.topics')
)
SELECT
  notice_id,
  topic.id
FROM
  cte
JOIN
  topic
ON
  cte.topic_name = topic.name
;
CREATE INDEX idx_notice_topic_topic_id ON notice_topic (topic_id);

--
-- notice_document
--
DROP TABLE IF EXISTS notice_document;
CREATE TABLE notice_document (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  notice_uid TEXT NOT NULL,
  url TEXT NOT NULL,
  description TEXT NOT NULL,
  FOREIGN KEY (notice_uid) REFERENCES notice(uid)
);
INSERT INTO notice_document (
  notice_uid,
  url,
  description
)
SELECT
  data.notice.noticeId,
  coalesce(json_each.value->>'$.url', ''),
  coalesce(json_each.value->>'$.description', '')
FROM
  data.notice,
  json_each(data.notice.json, '$.backgroundInformationList')
;

--
-- notice_reference
--
DROP TABLE IF EXISTS notice_reference;
CREATE TABLE notice_reference (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  notice_uid TEXT NOT NULL,
  url TEXT NOT NULL,
  description TEXT NOT NULL,
  FOREIGN KEY (notice_uid) REFERENCES notice(uid)
);
INSERT INTO notice_reference (
  notice_uid,
  url,
  description
)
SELECT
  data.notice.noticeId,
  coalesce(json_each.value->>'$.url', ''),
  coalesce(json_each.value->>'$.description', '')
FROM
  data.notice,
  json_each(data.notice.json, '$.otherReferenceList')
;

--
-- notice_planning_application_number
--
DROP TABLE IF EXISTS notice_planning_application_number;
CREATE TABLE notice_planning_application_number (
  notice_uid TEXT NOT NULL,
  number TEXT NOT NULL,
  PRIMARY KEY (notice_uid, number)
  FOREIGN KEY (notice_uid) REFERENCES notice (uid)
);
INSERT INTO notice_planning_application_number (
  notice_uid,
  number
)
SELECT
  data.notice.noticeId,
  json_each.value
FROM
  data.notice,
  json_each(data.notice.json, '$.planningApplicationNumbers')
;
