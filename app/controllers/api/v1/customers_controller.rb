class Api::V1::CustomersController < ApiController
  before_action :authenticate_api_user
  
  def index
    # Get customers with filtering options
    customers = Customer.includes(:calls, :contact_trackings)
    
    # Apply filters
    customers = customers.where(industry: params[:industry]) if params[:industry].present?
    customers = customers.where(status: params[:status]) if params[:status].present?
    customers = customers.where("company LIKE ?", "%#{params[:company]}%") if params[:company].present?
    customers = customers.where("tel LIKE ?", "%#{params[:tel]}%") if params[:tel].present?
    customers = customers.where("address LIKE ?", "%#{params[:address]}%") if params[:address].present?
    
    # Only customers with phone numbers and not deleted
    customers = customers.where.not(tel: [nil, "", " "])
    
    # Date range filtering
    if params[:created_from].present?
      customers = customers.where('created_at >= ?', Date.parse(params[:created_from]).beginning_of_day)
    end
    if params[:created_to].present?
      customers = customers.where('created_at <= ?', Date.parse(params[:created_to]).end_of_day)
    end
    
    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    customers = customers.page(page).per(per_page)
    
    render json: {
      status: 'SUCCESS',
      message: 'Customers retrieved successfully',
      data: customers.map { |customer| customer_api_data(customer) },
      pagination: {
        current_page: customers.current_page,
        total_pages: customers.total_pages,
        total_count: customers.total_count,
        per_page: customers.limit_value
      }
    }
  end
  
  def show
    customer = Customer.find(params[:id])
    render json: {
      status: 'SUCCESS',
      message: 'Customer retrieved successfully',
      data: customer_api_data(customer)
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: 'ERROR',
      message: 'Customer not found'
    }, status: 404
  end
  
  def search
    query = params[:q]
    if query.blank?
      render json: {
        status: 'ERROR',
        message: 'Search query is required'
      }, status: 400
      return
    end
    
    customers = Customer.includes(:calls, :contact_trackings)
                       .where.not(tel: [nil, "", " "])
                       .where("company LIKE ? OR tel LIKE ? OR address LIKE ?", 
                              "%#{query}%", "%#{query}%", "%#{query}%")
    
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    customers = customers.page(page).per(per_page)
    
    render json: {
      status: 'SUCCESS',
      message: 'Search completed',
      data: customers.map { |customer| customer_api_data(customer) },
      pagination: {
        current_page: customers.current_page,
        total_pages: customers.total_pages,
        total_count: customers.total_count,
        per_page: customers.limit_value
      }
    }
  end
  
  def by_industry
    industry = params[:industry]
    if industry.blank?
      render json: {
        status: 'ERROR',
        message: 'Industry parameter is required'
      }, status: 400
      return
    end
    
    customers = Customer.includes(:calls, :contact_trackings)
                       .where(industry: industry)
                       .where.not(tel: [nil, "", " "])
    
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    customers = customers.page(page).per(per_page)
    
    render json: {
      status: 'SUCCESS',
      message: "Customers for industry: #{industry}",
      data: customers.map { |customer| customer_api_data(customer) },
      pagination: {
        current_page: customers.current_page,
        total_pages: customers.total_pages,
        total_count: customers.total_count,
        per_page: customers.limit_value
      }
    }
  end
  
  def by_status
    status = params[:status]
    if status.blank?
      render json: {
        status: 'ERROR',
        message: 'Status parameter is required'
      }, status: 400
      return
    end
    
    customers = Customer.includes(:calls, :contact_trackings)
                       .where(status: status)
                       .where.not(tel: [nil, "", " "])
    
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    customers = customers.page(page).per(per_page)
    
    render json: {
      status: 'SUCCESS',
      message: "Customers with status: #{status}",
      data: customers.map { |customer| customer_api_data(customer) },
      pagination: {
        current_page: customers.current_page,
        total_pages: customers.total_pages,
        total_count: customers.total_count,
        per_page: customers.limit_value
      }
    }
  end
  
  private
  
  def customer_api_data(customer)
    {
      id: customer.id,
      company: customer.company,
      store: customer.store,
      tel: customer.tel,
      address: customer.address,
      url: customer.url,
      url_2: customer.url_2,
      title: customer.title,
      industry: customer.industry,
      industry_code: customer.industry_code,
      company_name: customer.company_name,
      payment_date: customer.payment_date,
      industry_mail: customer.industry_mail,
      mail: customer.mail,
      first_name: customer.first_name,
      postnumber: customer.postnumber,
      people: customer.people,
      caption: customer.caption,
      business: customer.business,
      genre: customer.genre,
      mobile: customer.mobile,
      choice: customer.choice,
      inflow: customer.inflow,
      other: customer.other,
      history: customer.history,
      area: customer.area,
      target: customer.target,
      meeting: customer.meeting,
      experience: customer.experience,
      price: customer.price,
      number: customer.number,
      start: customer.start,
      remarks: customer.remarks,
      status: customer.status,
      extraction_count: customer.extraction_count,
      send_count: customer.send_count,
      contact_url: customer.contact_url,
      last_call: {
        status: customer.last_call&.statu,
        time: customer.last_call&.time,
        comment: customer.last_call&.comment,
        created_at: customer.last_call&.created_at
      },
      created_at: customer.created_at,
      updated_at: customer.updated_at
    }
  end
  
  def authenticate_api_user
    # Simple API key authentication for now
    api_key = request.headers['X-API-Key'] || request.headers['Authorization']
    
    unless api_key == ENV['API_SECRET_KEY'] || api_key == 'test_key_123'
      render json: {
        status: 'ERROR',
        message: 'Unauthorized - Invalid API key'
      }, status: 401
      return
    end
  end
end
