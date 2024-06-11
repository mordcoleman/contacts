CREATE TABLE groups (
  id serial PRIMARY KEY,
  type text NOT NULL
);

CREATE TABLE contacts (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE,
  phone varchar(20) UNIQUE,
  email text UNIQUE
);

CREATE TABLE contact_groups (
  group_id INT REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  contact_id INT REFERENCES contacts(id) ON DELETE CASCADE NOT NULL,
  UNIQUE (group_id, contact_id)
);

INSERT INTO groups (type)
    VALUES ('Favorites'),
           ('Family'),
           ('Friends'),
           ('Work');

