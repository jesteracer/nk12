class CommissionsController < ApplicationController
  def index
    @uiks = Commission.find :all, :joins => :comments
    # Commission.includes([:comments]).where(:is_uik=>true)
  end

  def show
    @commission = Commission.find(params[:id])
    p = @commission.protocols
    @iik = p.first
    @checked_protocol = p[1] if p.count > 1
    @election = @commission.election
    if request.xhr?
    else
    end
  end

end
