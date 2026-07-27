class CreateImages < ActiveRecord::Migration[8.1]
  def change
    create_table :images do |t|
      t.string   :filename
      t.string   :caption
      t.jsonb    :tags, null: false, default: []
      t.boolean  :flagged, null: false, default: false
      t.datetime :flagged_at
      t.jsonb    :matched_terms, null: false, default: []
      t.datetime :last_scanned_at

      t.timestamps
    end
    add_index :images, :last_scanned_at
    add_index :images, :flagged
  end
end
