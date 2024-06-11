require "pg"

class DB_Persistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "contacts")
    end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def groups
    sql = <<~SQL
      SELECT groups.*
        FROM groups;
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_group_hash(tuple)
    end
  end

  def all_contacts
    sql = <<~SQL
      SELECT contacts.*
        FROM contacts
        ORDER BY contacts.name;
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_contact_hash(tuple)
    end
  end

  def create_new_contact(name, phone, email)
    sql = "INSERT INTO contacts (name, phone, email) VALUES ($1, $2, $3)"
    query(sql, name, phone, email )
  end

  def find_contact(id)
    sql = <<~SQL
      SELECT contacts.*
        FROM contacts
        WHERE contacts.id = $1;
    SQL
    result = query(sql, id)
    tuple_to_contact_hash(result.first)
  end

  def contact_match(query)
    results = []
    return results unless query

    sql = <<~SQL
      SELECT *
      FROM contacts
      WHERE name ILIKE $1;
    SQL
    result = query(sql, ('%' + query + '%'))

    result.each do |tuple|
      results << tuple_to_contact_hash(tuple)
    end
    results
  end

  def update_contact(name, phone, email, id)
    sql = "UPDATE contacts SET name = $1, phone = $2, email = $3 WHERE id = $4"
    query(sql, name, phone, email, id)
  end

  def delete_contact(id)
    query("DELETE FROM contacts WHERE id = $1", id)
  end

  def add_to_group(id, type)
    sql = "SELECT * FROM groups WHERE type = $1;"
    result = query(sql, type)

    group = tuple_to_group_hash(result.first)

    sql = "INSERT INTO contact_groups VALUES ($1, $2);"
    query(sql, group[:id], id)
  end

  def remove_from_group(id, group_id)
    sql = "DELETE FROM contact_groups WHERE contact_id = $1 AND group_id = $2"
    query(sql, id, group_id)
  end

  def get_group_type(id)
    sql = "SELECT groups.* FROM groups WHERE id = $1;"
    result = query(sql, id)

    tuple_to_group_hash(result.first)
  end

  def get_group_id(type)
    sql = "SELECT groups.* FROM groups WHERE type = $1;"
    result = query(sql, type)

    group = tuple_to_group_hash(result.first)
    group[:id]
  end

  def group_includes?(id, group_id)
    sql = <<~SQL
      SELECT count(contact_id)
      FROM contact_groups
      WHERE contact_id = $1 AND group_id = $2;
    SQL

    result = query(sql, id, group_id)
    result.first["count"].to_i != 0
  end

  def retrieve_group_contacts(group_id)
    sql = <<~SQL
      SELECT contacts.*
      FROM contacts
      INNER JOIN contact_groups ON contact_groups.contact_id = contacts.id
      INNER JOIN groups ON contact_groups.group_id = groups.id
      WHERE groups.id = $1;
    SQL

    result = query(sql, group_id)
    result.map do |tuple|
      tuple_to_contact_hash(tuple)
    end
  end

  def group_contacts_empty(id)
    sql = <<~SQL
      SELECT count(group_id)
      FROM contact_groups
      WHERE group_id = $1;
    SQL

    result = query(sql, id)
    result.first["count"].to_i == 0
  end

  private

  def tuple_to_group_hash(tuple)
    { id: tuple["id"].to_i,
      type: tuple["type"]
    }
  end

  def tuple_to_contact_hash(tuple)
    { id: tuple["id"].to_i,
        name: tuple["name"],
        phone: tuple["phone"],
        email: tuple["email"]
    }
  end
end
