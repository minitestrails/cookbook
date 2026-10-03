class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest

      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
  end
end
