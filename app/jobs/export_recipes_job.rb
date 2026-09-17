# app/jobs/export_recipes_job.rb
class ExportRecipesJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(user_id)
    user = User.find(user_id)
    recipes = Recipe.includes(:ingredients, :steps).order(:id)
    recipes_text = recipes.map { |recipe| render_recipe(recipe) }.join("\n\n")

    user.recipes_export.attach(
      io: StringIO.new(recipes_text),
      filename:
        "recipes-export-#{Time.current.utc.strftime("%Y%m%d%H%M%S")}.txt",
      content_type: "text/plain"
    )
    user.broadcast_replace_to(
      user,
      :recipes_export,
      target: ActionView::RecordIdentifier.dom_id(user, :recipes_export),
      partial: "recipes/export",
      locals: {
        user: user,
        ready: true
      }
    )
  end

  private

  def render_recipe(recipe)
    lines = [recipe.title, "", "Ingredients"]
    recipe.ingredients.each do |ingredient|
      amount = [ingredient.quantity, ingredient.unit].compact.join(" ")
      lines << "- #{ingredient.name} (#{amount})"
    end
    lines << ""
    lines << "Steps"
    recipe
      .steps
      .sort_by(&:position)
      .each { |step| lines << "#{step.position}. #{step.instruction}" }
    lines.join("\n")
  end
end
