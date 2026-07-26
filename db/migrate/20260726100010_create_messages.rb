class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.text     :body, null: false
      t.boolean  :flagged, null: false, default: false
      t.datetime :flagged_at
      t.jsonb    :matched_terms, null: false, default: []
      t.datetime :last_scanned_at

      t.timestamps
    end
    add_index :messages, :last_scanned_at
    add_index :messages, :flagged
  end
end
