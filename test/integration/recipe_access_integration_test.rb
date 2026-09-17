# test/integration/recipe_access_integration_test.rb
require "test_helper"

class RecipeAccessIntegrationTest < ActionDispatch::IntegrationTest
  test "guest cannot create a recipe" do
    get new_recipe_url
    assert_redirected_to new_session_url

    assert_no_difference("Recipe.count") do
      post recipes_url, params: { recipe: { title: "Sneaky soup" } }
    end
    assert_redirected_to new_session_url
  end

  test "guest cannot edit a recipe" do
    recipe = recipes(:pancakes)
    original_title = recipe.title

    get edit_recipe_url(recipe)
    assert_redirected_to new_session_url

    patch recipe_url(recipe), params: { recipe: { title: "Hacked title" } }
    assert_redirected_to new_session_url
    assert_equal original_title, recipe.reload.title
  end

  test "guest cannot destroy a recipe" do
    recipe = recipes(:lentil_soup)

    assert_no_difference("Recipe.count") { delete recipe_url(recipe) }
    assert_redirected_to new_session_url
  end

  test "signed-in user sees new recipe on the list" do
    sign_in_as users(:alice)

    get recipes_url
    assert_response :success
    assert_select "a", text: "New recipe"
    assert_select "button", text: "Destroy this recipe"
  end

  test "signed-in user sees edit and destroy on show" do
    sign_in_as users(:alice)

    get recipe_url(recipes(:pancakes))
    assert_response :success
    assert_select "a", text: "Edit this recipe"
    assert_select "button", text: "Destroy this recipe"
    assert_select "button", text: "Remove"
  end

  test "non-owner cannot update a recipe" do
    sign_in_as users(:bob)
    recipe = recipes(:pancakes)

    get edit_recipe_url(recipe)
    assert_redirected_to root_path

    patch recipe_url(recipe), params: { recipe: { title: "Hacked pancakes" } }
    assert_redirected_to root_path
    get recipe_url(recipe)
    assert_response :success
    assert_not_equal "Hacked pancakes", recipe.reload.title
  end

  test "non-owner cannot destroy a recipe" do
    sign_in_as users(:bob)
    recipe = recipes(:pancakes)

    assert_no_difference("Recipe.count") { delete recipe_url(recipe) }
    assert_redirected_to root_path
  end

  test "guest cannot remove an ingredient or a step from the detail page" do
    recipe = recipes(:pancakes)
    salt = ingredients(:salt)
    preheat = steps(:preheat)

    assert_no_difference("Ingredient.count") do
      delete recipe_ingredient_url(recipe, salt), as: :turbo_stream
    end
    assert_redirected_to new_session_url

    assert_no_difference("Step.count") do
      delete recipe_step_url(recipe, preheat), as: :turbo_stream
    end
    assert_redirected_to new_session_url

    get recipe_url(recipe)
    assert_response :success
    assert_match salt.name, response.body
    assert_match preheat.instruction, response.body
  end

  test "guest cannot remove an ingredient or a step when updating a recipe" do
    recipe = recipes(:pancakes)
    salt = ingredients(:salt)
    preheat = steps(:preheat)

    assert_no_difference("Ingredient.count", "Step.count") do
      patch recipe_url(recipe),
            params: {
              recipe: {
                ingredients_attributes: {
                  "0" => {
                    id: salt.id,
                    _destroy: "1"
                  }
                },
                steps_attributes: {
                  "0" => {
                    id: preheat.id,
                    _destroy: "1"
                  }
                }
              }
            }
    end
    assert_redirected_to new_session_url

    get recipe_url(recipe)
    assert_response :success
    assert_match salt.name, response.body
    assert_match preheat.instruction, response.body
  end

  test "non-owner cannot remove an ingredient or a step from the detail page" do
    sign_in_as users(:bob)
    recipe = recipes(:pancakes)
    salt = ingredients(:salt)
    preheat = steps(:preheat)

    assert_no_difference("Ingredient.count") do
      delete recipe_ingredient_url(recipe, salt), as: :turbo_stream
    end
    assert_redirected_to root_path

    assert_no_difference("Step.count") do
      delete recipe_step_url(recipe, preheat), as: :turbo_stream
    end
    assert_redirected_to root_path

    get recipe_url(recipe)
    assert_response :success
    assert_match salt.name, response.body
    assert_match preheat.instruction, response.body
  end

  test "non-owner cannot remove an ingredient or a step when updating a recipe" do
    sign_in_as users(:bob)
    recipe = recipes(:pancakes)
    salt = ingredients(:salt)
    preheat = steps(:preheat)

    assert_no_difference %w[Ingredient.count Step.count] do
      patch recipe_url(recipe),
            params: {
              recipe: {
                title: recipe.title,
                ingredients_attributes: {
                  "0" => {
                    id: salt.id,
                    _destroy: "1"
                  }
                },
                steps_attributes: {
                  "0" => {
                    id: preheat.id,
                    _destroy: "1"
                  }
                }
              }
            }
    end
    assert_redirected_to root_path

    get recipe_url(recipe)
    assert_response :success
    assert_match salt.name, response.body
    assert_match preheat.instruction, response.body
  end

  test "non-owner does not see change buttons" do
    sign_in_as users(:bob)

    get recipes_url
    assert_response :success
    assert_select "#recipe_#{recipes(:pancakes).id} button",
                  text: "Destroy this recipe",
                  count: 0

    get recipe_url(recipes(:pancakes))
    assert_response :success
    assert_match recipes(:pancakes).title, response.body
    assert_select "a", text: "Edit this recipe", count: 0
    assert_select "button", text: "Destroy this recipe", count: 0
    assert_select "button", text: "Remove", count: 0
  end

  test "guest cannot export recipes" do
    get recipes_url
    assert_response :success
    assert_select "button", text: "Export recipes", count: 0
    assert_select "a", text: "Download", count: 0

    assert_no_enqueued_jobs only: ExportRecipesJob do
      post export_recipes_url
    end
    assert_redirected_to new_session_url

    get download_recipes_url
    assert_redirected_to new_session_url
  end
end
