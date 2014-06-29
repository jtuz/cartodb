# coding: UTF-8
class Api::Json::RecordsController < Api::ApplicationController
  ssl_required :index, :create, :show, :update, :destroy

  REJECT_PARAMS = %W{ format controller action row_id requestId column_id
  api_key table_id oauth_token oauth_token_secret api_key user_domain }

  before_filter :load_table, :set_start_time

  #def index
    #render_jsonp(Yajl::Encoder.encode(@table.records(params.slice(:page, :rows_per_page, :order_by, :mode, :filter_column, :filter_value))))
  #rescue => e
    #CartoDB::Logger.info "exception on records#index", e.inspect
    #render_jsonp({ :errors => [e] }, 400)
  #end

  def create
    primary_key = @table.insert_row!(params.reject{|k,v| REJECT_PARAMS.include?(k)}.symbolize_keys)
    render_jsonp(get_record(primary_key))
  rescue => e
    render_jsonp({ :errors => [e.message] }, 400)
  end

  def show
    render_jsonp(get_record(params[:id]))
  rescue => e
    render_jsonp({ :errors => ["Record #{params[:id]} not found"] }, 404)
  end

  def update
    #TODO: security, check write permission
    unless params[:id].blank?
      begin
        resp = @table.update_row!(params[:id], params.reject{|k,v| REJECT_PARAMS.include?(k)}.symbolize_keys)
        if resp > 0
          render_jsonp(get_record(params[:id]))
        else
          render_jsonp({ :errors => ["row identified with #{params[:id]} not found"] }, 404) and return
        end
      rescue => e
        CartoDB::Logger.info e.backtrace.join('\n')
        render_jsonp({ :errors => [translate_error(e.message.split("\n").first)] }, 400) and return
      end
    else
      render_jsonp({ :errors => ["id can't be blank"] }, 404) and return
    end
  end

  def destroy
    #TODO: security, check write permission
    id = (params[:id] =~ /^\d+$/ ? params[:id] : params[:id].to_s.split(','))
    schema_name = current_user.database_schema
    if current_user.id != @table.owner.id
      schema_name = @table.owner.database_schema
    end
    current_user.in_database.select.from(@table.name.to_sym.qualify(schema_name.to_sym)).where(cartodb_id: id).delete
    head :no_content
  rescue => e
    render_jsonp({ errors: ["row identified with #{params[:id]} not found"] }, 404)
  end

  protected

  def get_record(id)
    @table.record(id)
  end

  def load_table
    @table = Table.get_by_id_or_name(params[:table_id], current_user)
    raise RecordNotFound if @table.nil?
  end
end
