class InvoicesController < ApplicationController

  def index
  	 @invoices = Invoice.all.order(created_at: 'desc')
  end
  
  def show
  	@invoice = Invoice.find(params[:id])
  end
  
  def new
    @invoice = Invoice.new
  end
 
 def create
    @invoice = Invoice.new(invoice_params)
    if @invoice.save
        # redirect
        redirect_to invoices_path
    else
        render 'new'
    end
  end
  
  def edit
    @invoice = Invoice.find(params[:id])
  end

 def update
    @invoice = Invoice.find(params[:id])
     if @invoice.update(invoice_params)
        redirect_to invoices_path
    else
        render 'edit'
    end      
 end
 
 def destroy
    @invoice = Invoice.find(params[:id])
    @invoice.destroy
    redirect_to invoices_path
 end
 


  # 帳票出力処理
  def report
    @invoice = Invoice.find(params[:id])
    report = Thinreports::Report.new layout: "app/reports/layouts/invoices.tlf"
    report.start_new_page
    report.page.values(
    created_at: @invoice.try(:created_at),
    company: @invoice.try("@invoice.company.company"), #@companyのcompany
    postnumber: @invoice.try("@invoice.company.postnumber"), #@companyのpostnumber
    address: @invoice.try("@invoice.company.address"), #@companyのaddress
    first_name: @invoice.try("@invoice.company.first_name"), #@companyのfirst_name
    last_name: @invoice.try("@invoice.company.last_name"), #@companyのlast_name
    
    )
    send_data(report.generate, filename: "#{@invoice}.pdf", type: "application/pdf")
  end



  private
    def invoice_params
      params.require(:invoice).permit(
        :status, #ステータス
        :deadline, #期限
        :payment,#入金日
        :subject, #件名
        :item1, #商品名
        :item2, #商品名
        :item3, #商品名
        :item4, #商品名
        :item5, #商品名

        :price1, #商品名
        :price2, #商品名
        :price3, #商品名
        :price4, #商品名
        :price5, #商品名

        :quantity1, #数量
        :quantity2, #数量
        :quantity3, #数量
        :quantity4, #数量
        :quantity5 #数量

        )
    end    



end
