# test/jobs/export_recipes_job_test.rb
require "test_helper"

class ExportRecipesJobTest < ActiveJob::TestCase
  test "exports all recipes in the app" do
    user = users(:alice)

    assert_not user.recipes_export.attached?

    ExportRecipesJob.perform_now(user.id)

    user.reload
    assert user.recipes_export.attached?
    assert_match(
      /\Arecipes-export-\d{14}\.txt\z/,
      user.recipes_export.filename.to_s
    )
    contents = user.recipes_export.download
    assert_includes contents, "Fluffy pancakes"
    assert_includes contents, "Lentil soup"
    assert_includes contents, "Pizza"
    assert_includes contents, "Flour"
    assert_includes contents, "Cheese"
  end

  test "discards the export when the user is deleted" do
    user_id = users(:bob).id
    users(:bob).destroy!

    assert_no_difference "ActiveStorage::Blob.count" do
      ExportRecipesJob.perform_now(user_id)
    end
  end
end
