class GenderizeIoRb::DatabaseSchema
  SCHEMA = {
    tables: {
      genderize_io_rb_cache: {
        columns: [
          {name: :id, type: :int, autoincr: true, primarykey: true},
          {name: :name, type: :varchar},
          {name: :result, type: :text},
          {name: :created_at, type: :datetime}
        ],
        indexes: [
          {name: :name, columns: [:name], unique: true}
        ]
      }
    }
  }
end
