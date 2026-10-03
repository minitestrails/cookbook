# test/controllers/api/v1/recipe_access_controller_test.rb
require "api_test_case"

class Api::V1::RecipeAccessControllerTest < ApiTestCase
  test "guest cannot create a recipe" do
    assert_no_difference "Recipe.count" do
      post api_v1_recipes_url,
           params: {
             recipe: {
               title: "API pancakes"
             }
           },
           as: :json
    end
    assert_response :unauthorized
  end

  test "guest cannot edit a recipe" do
    recipe = recipes(:pancakes)
    original_title = recipe.title

    patch api_v1_recipe_url(recipe),
          params: {
            recipe: {
              title: "API pancakes"
            }
          },
          as: :json

    assert_response :unauthorized
    assert_equal original_title, recipe.reload.title
  end

  test "guest cannot destroy a recipe" do
    recipe = recipes(:pancakes)
    assert_no_difference "Recipe.count" do
      delete api_v1_recipe_url(recipe), as: :json
    end
    assert_response :unauthorized
  end

  test "guest cannot export recipes" do
    assert_no_enqueued_jobs only: ExportRecipesJob do
      post export_api_v1_recipes_url, as: :json
    end
    assert_response :unauthorized
  end

  test "guest cannot download an export" do
    get download_api_v1_recipes_url, as: :json
    assert_response :unauthorized
  end

  test "cannot update recipe of another user" do
    recipe = recipes(:pancakes)
    original_title = recipe.title

    patch api_v1_recipe_url(recipe),
          params: {
            recipe: {
              title: "Bob was here"
            }
          },
          headers: bearer_token_for(users(:bob)),
          as: :json

    assert_response :forbidden
    assert_equal original_title, recipe.reload.title
  end

  test "cannot destroy recipe of another user" do
    recipe = recipes(:pancakes)

    assert_no_difference "Recipe.count" do
      delete api_v1_recipe_url(recipe),
             headers: bearer_token_for(users(:bob)),
             as: :json
    end

    assert_response :forbidden
  end
end
