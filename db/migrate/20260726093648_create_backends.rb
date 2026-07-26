class CreateBackends < ActiveRecord::Migration[8.1]
  def change
    create_table :backends do |t|
      t.string :host, null: false
      t.integer :weight, null: false, default: 1
      t.integer :active_connections, null: false, default: 0
      t.integer :times_selected, null: false, default: 0
      t.boolean :healthy, null: false, default: true

      t.timestamps
    end
    add_index :backends, :host, unique: true
  end
end
