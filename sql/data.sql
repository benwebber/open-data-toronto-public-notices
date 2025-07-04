DROP TABLE IF EXISTS notice;
CREATE TABLE IF NOT EXISTS notice (
  noticeId TEXT NOT NULL PRIMARY KEY,
  json TEXT NOT NULL,
  title AS (json->>'$.title'),
  subheading AS (json->>'$.subheading'),
  decisionBody AS (json->>'$.decisionBody'),
  noticeDescription AS (json->>'$.noticeDescription'),
  noticeDate AS (json->>'$.noticeDate'),
  eventList AS (json->>'$.eventList'),
  addressList AS (json->>'$.addressList'),
  topics AS (json->>'$.topics'),
  planningApplicationNumbers AS (json->>'$.planningApplicationNumbers'),
  documents AS (json->>'$.backgroundInformationList'),
  otherReferenceList AS (json->>'$.otherReferenceList'),
  contact AS (json->>'$.contact'),
  signedBy AS (json->>'$.signedBy')
);
