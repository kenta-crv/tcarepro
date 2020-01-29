class InvoicesController < ApplicationController
  before_action :authenticate_admin!
  def new
    @crm = Crm.find(params[:crm_id])
    @invoice = @crm.invoices.new
  end

  def show
    @crm = Crm.find(params[:crm_id])
    @invoice = @crm.invoices.find(params[:id])
  end

  def create
    @crm = Crm.find(params[:crm_id])
    @invoice = @crm.invoices.create(invoice_params)
    redirect_to crm_path(@crm)
  end

  def destroy
    @crm = Crm.find(params[:crm_id])
    @invoice = @crm.invoices.find(params[:id])
    @invoice.destroy
    redirect_to crm_path(@crm)
  end

  # 帳票出力処理
  def report
    @invoice = Invoice.find(params[:id])
    report = Thinreports::Report.new layout: "app/reports/layouts/invoices.tlf"
    report.start_new_page
    report.page.values(
    created_at: @invoice.try(:created_at),
    company: @invoice.company.try(:company),
    first_name: @invoice.company.try(:first_name),
    postnumber: @invoice.company.try(:postnumber),
    address: @invoice.company.try(:address),
    address2: @invoice.company.try(:town),

    item1: @invoice.try(:item1),
    price1: @invoice.try(:price1),
    quantity1: @invoice.try(:quantity1),
    total1: @invoice.try(:calc1),

    item2: @invoice.try(:item2),
    price2: @invoice.try(:price2),
    quantity2: @invoice.try(:quantity2),
    total2: @invoice.try(:calc2),

    item2: @invoice.try(:item2),
    price2: @invoice.try(:price2),
    quantity2: @invoice.try(:quantity2),
    total2: @invoice.try(:calc2),

    item3: @invoice.try(:item3),
    price3: @invoice.try(:price3),
    quantity3: @invoice.try(:quantity3),
    total3: @invoice.try(:calc3),

    item4: @invoice.try(:item4),
    price4: @invoice.try(:price4),
    quantity4: @invoice.try(:quantity4),
    total4: @invoice.try(:calc4),

    item5: @invoice.try(:item5),
    price5: @invoice.try(:price5),
    quantity5: @invoice.try(:quantity5),
    total5: @invoice.try(:calc5),

    subtotal: @invoice.try(:summary),
    tax: @invoice.try(:tax),
    all: @invoice.try(:total),
    all2: @invoice.try(:total),
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
