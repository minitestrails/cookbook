# test/integration/recipes_integration_test.rb
require "test_helper"

class RecipesIntegrationTest < ActionDispatch::IntegrationTest
  test "visits the list" do
    get recipes_url
    assert_response :success
    assert_match "Recipes", response.body
    assert_match recipes(:pancakes).title, response.body
    assert_select "#recipes div[id^='recipe_']", count: Recipe.count
    assert_select "a", text: "New recipe", count: 0
    assert_select "button", text: "Destroy this recipe", count: 0
  end

  test "shows a recipe" do
    get recipe_url(recipes(:pancakes))
    assert_response :success
    assert_match recipes(:pancakes).title, response.body
    assert_select "a", text: "Edit this recipe", count: 0
    assert_select "button", text: "Destroy this recipe", count: 0
  end

  test "shows ingredients and steps on the recipe page" do
    get recipe_url(recipes(:pancakes))
    assert_response :success
    assert_match recipes(:pancakes).title, response.body
    assert_select "h2", "Ingredients"
    assert_match "Salt (1 pinch)", response.body
    assert_match "Flour (2 cups)", response.body
    assert_select "h2", "Steps"
    assert_match steps(:preheat).instruction, response.body
    assert_select "button", text: "Remove", count: 0
  end

  test "creates a recipe" do
    sign_in_as users(:alice)

    get new_recipe_url
    assert_response :success
    assert_match "New recipe", response.body

    assert_difference("Recipe.count", 1) do
      post recipes_url, params: { recipe: { title: "Lentil soup" } }
    end
    assert_redirected_to recipe_url(Recipe.last)
    follow_redirect!
    assert_response :success
    assert_match "Lentil soup", response.body
  end

  test "creates a recipe with an ingredient and a step" do
    sign_in_as users(:alice)

    get new_recipe_url
    assert_response :success
    assert_match "New recipe", response.body
    assert_select "h2", "Ingredients"
    assert_select "h2", "Steps"

    assert_difference %w[Recipe.count Ingredient.count Step.count], 1 do
      post recipes_url,
           params: {
             recipe: {
               title: "Tomato soup",
               ingredients_attributes: {
                 "0" => {
                   name: "Tomatoes",
                   quantity: "400",
                   unit: "g"
                 }
               },
               steps_attributes: {
                 "0" => {
                   position: "1",
                   instruction: "Simmer until the tomatoes soften"
                 }
               }
             }
           }
    end
    assert_redirected_to recipe_url(Recipe.last)
    follow_redirect!
    assert_response :success
    assert_match "Tomatoes (400 g)", response.body
    assert_match "Simmer until the tomatoes soften", response.body
  end

  test "does not create a recipe with invalid data" do
    sign_in_as users(:alice)

    assert_no_difference("Recipe.count") do
      post recipes_url, params: { recipe: { title: "" } }
    end
    assert_response :unprocessable_entity
    assert_match /prohibited this recipe from being saved/i, response.body
    assert_select "h1", "New recipe"
  end

  test "does not create a recipe with invalid ingredient" do
    sign_in_as users(:alice)

    assert_no_difference %w[Recipe.count Ingredient.count] do
      post recipes_url,
           params: {
             recipe: {
               title: "Tomato soup",
               ingredients_attributes: {
                 "0" => {
                   name: "Tomatoes",
                   quantity: "-1",
                   unit: "cups"
                 }
               }
             }
           }
    end
    assert_response :unprocessable_entity
    assert_match /prohibited this recipe from being saved/i, response.body
    assert_match /ingredients quantity must be greater than 0/i, response.body
    assert_select "h1", "New recipe"
  end

  test "does not create a recipe with invalid step" do
    sign_in_as users(:alice)

    assert_no_difference %w[Recipe.count Step.count] do
      post recipes_url,
           params: {
             recipe: {
               title: "Tomato soup",
               steps_attributes: {
                 "0" => {
                   position: "1",
                   instruction: ""
                 }
               }
             }
           }
    end
    assert_response :unprocessable_entity
    assert_match /prohibited this recipe from being saved/i, response.body
    assert_select "li", text: /steps instruction can't be blank/i
    assert_select "h1", "New recipe"
  end

  test "updates a recipe" do
    sign_in_as users(:alice)
    recipe = recipes(:pancakes)

    get edit_recipe_url(recipe)
    assert_response :success
    assert_select "h1", "Editing recipe"

    patch recipe_url(recipe),
          params: {
            recipe: {
              title: "Extra fluffy pancakes"
            }
          }
    assert_redirected_to recipe_url(recipe)
    follow_redirect!
    assert_response :success
    assert_match "Extra fluffy pancakes", response.body
  end

  test "adds an ingredient and a step when editing a recipe" do
    sign_in_as users(:alice)
    recipe = recipes(:pancakes)

    assert_difference %w[Ingredient.count Step.count], 1 do
      patch recipe_url(recipe),
            params: {
              recipe: {
                title: recipe.title,
                ingredients_attributes: {
                  "0" => {
                    name: "Pepper",
                    quantity: "1",
                    unit: "pinch"
                  }
                },
                steps_attributes: {
                  "0" => {
                    position: "2",
                    instruction: "Flip and serve."
                  }
                }
              }
            }
    end
    assert_redirected_to recipe_url(recipe)
    follow_redirect!
    assert_response :success
    assert_match "Pepper (1 pinch)", response.body
    assert_match "Flip and serve.", response.body
  end

  test "destroys a recipe" do
    sign_in_as users(:alice)
    recipe = recipes(:lentil_soup)

    assert_difference("Recipe.count", -1) { delete recipe_url(recipe) }
    assert_redirected_to recipes_url
    follow_redirect!
    assert_response :success
    assert_select "#recipes div[id^='recipe_']", count: Recipe.count
  end

  test "filters the list to quick recipes" do
    get recipes_url
    assert_response :success
    assert_select "form.recipe-filters"
    assert_select "select#quick"

    get recipes_url, params: { quick: "1" }
    assert_response :success
    assert_match recipes(:pancakes).title, response.body
    assert_no_match recipes(:lentil_soup).title, response.body
  end

  test "removes existing ingredients and steps when updating a recipe" do
    sign_in_as users(:alice)

    recipe = recipes(:pancakes)
    salt = ingredients(:salt)
    preheat = steps(:preheat)

    assert_difference %w[Ingredient.count Step.count], -1 do
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

    assert_redirected_to recipe_url(recipe)
    follow_redirect!
    assert_response :success
    assert_no_match salt.name, response.body
    assert_no_match preheat.instruction, response.body
    assert_match "Flour (2 cups)", response.body
  end

  test "removes ingredients and steps from the detail page" do
    sign_in_as users(:alice)

    recipe = recipes(:pancakes)
    salt = ingredients(:salt)
    preheat = steps(:preheat)

    assert_difference %w[Ingredient.count Step.count], -1 do
      delete recipe_ingredient_url(recipe, salt), as: :turbo_stream
      delete recipe_step_url(recipe, preheat), as: :turbo_stream
    end

    get recipe_url(recipe)
    assert_response :success
    assert_no_match salt.name, response.body
    assert_no_match preheat.instruction, response.body
    assert_match "Flour (2 cups)", response.body
  end

  test "shares a recipe" do
    sender = users(:alice)
    recipe = recipes(:pancakes)

    sign_in_as sender

    get recipe_url(recipe)
    assert_response :success
    assert_select "dialog"
    assert_select "input[name='recipe[recipient_email]']"

    assert_enqueued_email_with RecipeMailer,
                               :share,
                               args: [
                                 recipe,
                                 "friend@example.com",
                                 sender.email_address
                               ] do
      post share_recipe_url(recipe),
           params: {
             recipe: {
               recipient_email: "friend@example.com"
             }
           }
    end

    assert_redirected_to recipe_url(recipe)
    follow_redirect!
    assert_response :success
    assert_match recipe.title, response.body
  end

  test "guest shares a recipe" do
    recipe = recipes(:pancakes)

    assert_enqueued_email_with RecipeMailer,
                               :share,
                               args: [recipe, "friend@example.com", nil] do
      post share_recipe_url(recipe),
           params: {
             recipe: {
               recipient_email: "friend@example.com"
             }
           }
    end

    assert_redirected_to recipe_url(recipe)
    follow_redirect!
    assert_response :success
    assert_match recipe.title, response.body
  end

  test "exports recipes" do
    sign_in_as users(:alice)

    get recipes_url
    assert_response :success
    assert_select "button", text: "Export recipes"
    assert_select "a", text: "Download", count: 0

    assert_enqueued_with(job: ExportRecipesJob, args: [users(:alice).id]) do
      post export_recipes_url
    end

    assert_response :success
    assert_equal "Your recipes are being exported.", flash.notice
  end

  test "downloads the export file" do
    sign_in_as users(:alice)
    user = users(:alice)

    ExportRecipesJob.perform_now(user.id)

    get download_recipes_url
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_match(
      /recipes-export-\d{14}\.txt/,
      response.headers["Content-Disposition"]
    )
    assert_includes response.body, recipes(:pancakes).title
    assert_includes response.body, recipes(:lentil_soup).title
    assert_includes response.body, "Flour"
  end

  test "redirects to index page if export file is missing for the user" do
    sign_in_as users(:alice)

    get download_recipes_url

    assert_redirected_to recipes_url
    follow_redirect!
    assert_equal "Export file is not ready yet.", flash.alert
  end
end
