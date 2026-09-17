class RecipesController < ApplicationController
  allow_unauthenticated_access only: %i[index show share]
  before_action :set_recipe, only: %i[show edit update destroy share]

  # GET /recipes or /recipes.json
  def index
    @recipes = params[:quick] == "1" ? Recipe.quick : Recipe.all
  end

  # GET /recipes/1 or /recipes/1.json
  def show
  end

  # GET /recipes/new
  def new
    @recipe = Recipe.new

    authorize! @recipe

    @recipe.ingredients.build
    @recipe.steps.build
  end

  # GET /recipes/1/edit
  def edit
    authorize! @recipe
  end

  # POST /recipes or /recipes.json
  def create
    @recipe = current_user.recipes.build(recipe_params)

    authorize! @recipe

    respond_to do |format|
      if @recipe.save
        format.html do
          redirect_to @recipe, notice: "Recipe was successfully created."
        end
        format.json { render :show, status: :created, location: @recipe }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json do
          render json: @recipe.errors, status: :unprocessable_entity
        end
      end
    end
  end

  # PATCH/PUT /recipes/1 or /recipes/1.json
  def update
    authorize! @recipe

    respond_to do |format|
      if @recipe.update(recipe_params)
        format.html do
          redirect_to @recipe,
                      notice: "Recipe was successfully updated.",
                      status: :see_other
        end
        format.json { render :show, status: :ok, location: @recipe }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: @recipe.errors, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /recipes/1 or /recipes/1.json
  def destroy
    authorize! @recipe

    @recipe.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@recipe) }
      format.html do
        redirect_to recipes_path,
                    notice: "Recipe was successfully destroyed.",
                    status: :see_other
      end
      format.json { head :no_content }
    end
  end

  def share
    recipient = params[:recipe][:recipient_email]
    sender = current_user&.email_address

    RecipeMailer.share(@recipe, recipient, sender).deliver_later

    redirect_to @recipe, notice: "Recipe shared with #{recipient}."
  end

  def export
    ExportRecipesJob.perform_later(current_user.id)

    flash.now[:notice] = "Your recipes are being exported."

    render turbo_stream: turbo_stream.update("flash", partial: "shared/flash")
  end

  def download
    unless current_user.recipes_export.attached?
      redirect_to recipes_path, alert: "Export file is not ready yet."
      return
    end

    send_data current_user.recipes_export.download,
              filename: current_user.recipes_export.filename.to_s,
              type: current_user.recipes_export.content_type || "text/plain",
              disposition: :attachment
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_recipe
    @recipe = Recipe.find(params.expect(:id))
  end

  # Only allow a list of trusted parameters through.
  def recipe_params
    params.expect(
      recipe: [
        :title,
        :description,
        :prep_time,
        :servings,
        {
          ingredients_attributes: [%i[id name quantity unit _destroy]],
          steps_attributes: [%i[id position instruction _destroy]]
        }
      ]
    )
  end
end
