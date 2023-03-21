class PybotENotifyController < ApplicationController
    def index
        @pynotify = Pynotify.all
    end

    def destroyer
        @pynotify = Pynotify.destroy_all
        redirect_to "/pybot"
    end
end
