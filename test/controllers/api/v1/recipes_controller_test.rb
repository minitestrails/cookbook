# test/controllers/api/v1/recipes_controller_test.rb
require "api_test_case"

class Api::V1::RecipesControllerTest < ApiTestCase
  test "lists recipes" do
    get api_v1_recipes_url, as: :json

    assert_response :success
    assert_equal "application/json", response.media_type

    titles = response.parsed_body.fetch("recipes").map { _1["title"] }
    assert_includes titles, recipes(:pancakes).title
  end

  test "filters quick recipes" do
    get api_v1_recipes_url, params: { quick: "1" }, as: :json

    assert_response :success
    titles = response.parsed_body.fetch("recipes").map { _1["title"] }
    assert_includes titles, recipes(:pancakes).title
    assert_not_includes titles, recipes(:pizza).title
  end

  test "shows a recipe" do
    get api_v1_recipe_url(recipes(:pancakes)), as: :json

    assert_response :success
    recipe = response.parsed_body.fetch("recipe")
    assert_equal recipes(:pancakes).title, recipe["title"]
    assert_equal %w[id ingredients prep_time steps title].sort, recipe.keys.sort
  end

  test "shows not found for a missing recipe" do
    get api_v1_recipe_url(id: 0), as: :json

    assert_response :not_found
    assert_equal "Not found", response.parsed_body["error"]
  end

  test "creates a recipe" do
    assert_difference "Recipe.count", 1 do
      post api_v1_recipes_url,
           params: {
             recipe: {
               title: "API stew"
             }
           },
           headers: bearer_token_for(users(:alice)),
           as: :json
    end

    assert_response :created
    assert_equal "API stew", response.parsed_body.dig("recipe", "title")
  end

  test "does not create a recipe with invalid attributes" do
    assert_no_difference "Recipe.count" do
      post api_v1_recipes_url,
           params: {
             recipe: {
               title: ""
             }
           },
           headers: bearer_token_for(users(:alice)),
           as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  test "creates a recipe with nested ingredient and step" do
    assert_difference -> { Recipe.count } => 1,
                      -> { Ingredient.count } => 1,
                      -> { Step.count } => 1 do
      post api_v1_recipes_url,
           params: {
             recipe: {
               title: "API stew",
               ingredients_attributes: {
                 "0" => {
                   name: "Paprika",
                   quantity: 1,
                   unit: "tsp"
                 }
               },
               steps_attributes: {
                 "0" => {
                   instruction: "Boil the water"
                 }
               }
             }
           },
           headers: bearer_token_for(users(:alice)),
           as: :json
    end

    assert_response :created
    assert_equal "Paprika", Recipe.order(:id).last.ingredients.first.name
    assert_equal "Boil the water",
                 Recipe.order(:id).last.steps.first.instruction
  end

  test "does not create a recipe with invalid nested attributes" do
    assert_no_difference %w[Recipe.count Ingredient.count Step.count] do
      post api_v1_recipes_url,
           params: {
             recipe: {
               title: "API stew",
               ingredients_attributes: {
                 "0" => {
                   name: ""
                 }
               },
               steps_attributes: {
                 "0" => {
                   instruction: ""
                 }
               }
             }
           },
           headers: bearer_token_for(users(:alice)),
           as: :json
    end

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  test "updates a recipe" do
    recipe = recipes(:pancakes)

    patch api_v1_recipe_url(recipe),
          params: {
            recipe: {
              title: "API pancakes"
            }
          },
          headers: bearer_token_for(users(:alice)),
          as: :json

    assert_response :success
    assert_equal "API pancakes", response.parsed_body.dig("recipe", "title")
    assert_equal "API pancakes", recipe.reload.title
  end

  test "does not update a recipe with invalid attributes" do
    recipe = recipes(:pancakes)
    original_title = recipe.title

    patch api_v1_recipe_url(recipe),
          params: {
            recipe: {
              title: ""
            }
          },
          headers: bearer_token_for(users(:alice)),
          as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
    assert_equal original_title, recipe.reload.title
  end

  test "destroys a recipe" do
    recipe = recipes(:pancakes)

    assert_difference "Recipe.count", -1 do
      delete api_v1_recipe_url(recipe),
             headers: bearer_token_for(users(:alice)),
             as: :json
    end

    assert_response :no_content
  end

  test "shares a recipe" do
    recipe = recipes(:pancakes)
    sender = users(:alice)

    assert_enqueued_email_with RecipeMailer,
                               :share,
                               args: [
                                 recipe,
                                 "friend@example.com",
                                 sender.email_address
                               ] do
      post share_api_v1_recipe_url(recipe),
           params: {
             recipe: {
               recipient_email: "friend@example.com"
             }
           },
           headers: bearer_token_for(sender),
           as: :json
    end

    assert_response :success
    assert_equal "Recipe shared with friend@example.com.",
                 response.parsed_body["message"]
  end

  test "guest shares a recipe" do
    recipe = recipes(:pancakes)

    assert_enqueued_email_with RecipeMailer,
                               :share,
                               args: [recipe, "friend@example.com", nil] do
      post share_api_v1_recipe_url(recipe),
           params: {
             recipe: {
               recipient_email: "friend@example.com"
             }
           },
           as: :json
    end

    assert_response :success
    assert_equal "Recipe shared with friend@example.com.",
                 response.parsed_body["message"]
  end

  test "exports recipes" do
    assert_enqueued_with(job: ExportRecipesJob, args: [users(:alice).id]) do
      post export_api_v1_recipes_url,
           headers: bearer_token_for(users(:alice)),
           as: :json
    end

    assert_response :success
    assert_equal "Your recipes are being exported.",
                 response.parsed_body["message"]
  end

  test "rejects download when export is missing" do
    get download_api_v1_recipes_url,
        headers: bearer_token_for(users(:alice)),
        as: :json

    assert_response :not_found
  end

  test "downloads exported recipes" do
    ExportRecipesJob.perform_now(users(:alice).id)

    get download_api_v1_recipes_url, headers: bearer_token_for(users(:alice))

    assert_response :success
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_match(
      /recipes-export-\d{14}\.txt/,
      response.headers["Content-Disposition"]
    )
    assert_includes response.body, recipes(:pancakes).title
  end
end
