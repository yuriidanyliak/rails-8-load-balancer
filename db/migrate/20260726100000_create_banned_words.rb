class CreateBannedWords < ActiveRecord::Migration[8.1]
  def change
    create_table :banned_words do |t|
      t.string  :phrase, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :banned_words, "lower(phrase)", unique: true, name: "index_banned_words_on_lower_phrase"
  end
end
