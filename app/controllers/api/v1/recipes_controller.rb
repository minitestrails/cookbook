# app/controllers/api/v1/recipes_controller.rb
class Api::V1::RecipesController < ApiController
  allow_unauthenticated_access only: %i[index show share]
  before_action :set_recipe, only: %i[show update destroy share]

  def index
    recipes = params[:quick] == "1" ? Recipe.quick : Recipe.all

    render json: { recipes: recipes.as_json(only: %i[id title prep_time]) }
  end

  def show
    render json: { recipe: recipe_json(@recipe) }
  end

  def create
    recipe = current_user.recipes.build(recipe_params)
    authorize! recipe

    if recipe.save
      render json: { recipe: recipe_json(recipe) }, status: :created
    else
      render json: {
               errors: recipe.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  def update
    authorize! @recipe

    if @recipe.update(recipe_params)
      render json: { recipe: recipe_json(@recipe) }
    else
      render json: {
               errors: @recipe.errors.full_messages
             },
             status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @recipe

    @recipe.destroy!

    head :no_content
  end

  def share
    recipient = params[:recipe][:recipient_email]
    sender = current_user&.email_address

    RecipeMailer.share(@recipe, recipient, sender).deliver_later

    render json: { message: "Recipe shared with #{recipient}." }
  end

  def export
    ExportRecipesJob.perform_later(current_user.id)

    render json: { message: "Your recipes are being exported." }
  end

  def download
    unless current_user.recipes_export.attached?
      head :not_found
      return
    end

    send_data current_user.recipes_export.download,
              filename: current_user.recipes_export.filename.to_s,
              type: current_user.recipes_export.content_type || "text/plain",
              disposition: :attachment
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(
      :title,
      :description,
      :servings,
      :prep_time,
      ingredients_attributes: [%i[name quantity unit]],
      steps_attributes: [%i[instruction position]]
    )
  end

  def recipe_json(recipe)
    recipe.as_json(
      only: %i[id title prep_time],
      include: {
        ingredients: {
          only: %i[name quantity unit]
        },
        steps: {
          only: %i[position instruction]
        }
      }
    )
  end
end
