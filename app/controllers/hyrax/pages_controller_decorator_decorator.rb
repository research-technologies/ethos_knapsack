# frozen_string_literal: true
module Hyrax
  # Shows the about and help page
  module PagesControllerDecoratorDecorator
    private

    def permitted_params
      params.require(:content_block).permit(:about,
                                            :agreement,
                                            :help,
                                            :terms,
                                            :contact_us)
    end
  end
end

Hyrax::PagesControllerDecorator.prepend Hyrax::PagesControllerDecoratorDecorator
