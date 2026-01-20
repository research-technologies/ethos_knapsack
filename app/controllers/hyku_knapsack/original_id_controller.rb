# frozen_string_literal: true
module HykuKnapsack
  class OriginalIdController < ApplicationController
    def show
      original_id = params[:uin]
      hit = ::Hyrax::SolrService.query("ethos_identifier_ssi:#{original_id}", rows: 1, fl: 'id,has_model_ssim').first
      return redirect_to hyrax.root_path, alert: "Item with identifier #{params[:uin]} not found." if hit.blank?

      id = hit['id']
      model = hit['has_model_ssim'].first
      redirect_to "/concern/#{model.underscore.pluralize}/#{id}"
    end
  end
end
