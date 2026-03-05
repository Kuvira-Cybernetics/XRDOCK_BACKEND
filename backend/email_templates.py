def _get_base_html(title: str, preheader: str, body_content: str, footer_content: str) -> str:
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{title}</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                background-color: #f4f4f5;
                margin: 0;
                padding: 0;
                -webkit-font-smoothing: antialiased;
            }}
            .wrapper {{
                width: 100%;
                table-layout: fixed;
                background-color: #f4f4f5;
                padding-bottom: 60px;
                padding-top: 40px;
            }}
            .main {{
                margin: 0 auto;
                width: 100%;
                max-width: 600px;
                background-color: #ffffff;
                border-radius: 12px;
                box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
                overflow: hidden;
            }}
            .header {{
                background-color: #0f172a;
                padding: 32px 40px;
                text-align: center;
                border-bottom: 4px solid #6366f1;
            }}
            .header img {{
                max-width: 200px;
                height: auto;
                display: block;
                margin: 0 auto;
            }}
            .content {{
                padding: 40px;
                color: #334155;
            }}
            .greeting {{
                font-size: 18px;
                font-weight: 600;
                margin-bottom: 24px;
                color: #0f172a;
            }}
            .detail-card {{
                background-color: #f8fafc;
                border: 1px solid #e2e8f0;
                border-radius: 8px;
                padding: 24px;
                margin-bottom: 24px;
            }}
            .detail-row {{
                margin-bottom: 16px;
            }}
            .detail-row:last-child {{
                margin-bottom: 0;
            }}
            .label {{
                font-size: 12px;
                text-transform: uppercase;
                letter-spacing: 1px;
                color: #64748b;
                font-weight: 600;
                margin-bottom: 4px;
                display: block;
            }}
            .value {{
                font-size: 16px;
                color: #0f172a;
                font-weight: 500;
            }}
            .message-box {{
                background-color: #ffffff;
                border: 1px solid #e2e8f0;
                border-radius: 6px;
                padding: 16px;
                font-size: 15px;
                line-height: 1.6;
                color: #334155;
                white-space: pre-wrap;
            }}
            .footer {{
                background-color: #f8fafc;
                padding: 24px 40px;
                text-align: center;
                border-top: 1px solid #e2e8f0;
            }}
            .footer p {{
                margin: 0;
                font-size: 13px;
                color: #64748b;
                line-height: 1.5;
            }}
        </style>
    </head>
    <body>
        <div style="display: none; max-height: 0px; overflow: hidden;">{preheader}</div>
        <div class="wrapper">
            <table class="main" width="100%" cellpadding="0" cellspacing="0" role="presentation">
                <tr>
                    <td>
                        <div class="header">
                            <img src="cid:xrdock_logo" alt="XR-DOCK Logo" />
                        </div>
                        <div class="content">
                            {body_content}
                        </div>
                        <div class="footer">
                            {footer_content}
                        </div>
                    </td>
                </tr>
            </table>
        </div>
    </body>
    </html>
    """

def get_sales_notification_email_html(name: str, email: str, message: str) -> str:
    body = f"""
    <div class="greeting">New Contact Request Received</div>
    <p style="margin-top: 0; margin-bottom: 24px; font-size: 15px; line-height: 1.5;">You have received a new inquiry from the XR-DOCK pricing page. Details are below:</p>
    
    <div class="detail-card">
        <div class="detail-row">
            <span class="label">Name</span>
            <span class="value">{name}</span>
        </div>
        <div class="detail-row">
            <span class="label">Email Address</span>
            <span class="value"><a href="mailto:{email}" style="color: #6366f1; text-decoration: none;">{email}</a></span>
        </div>
        <div class="detail-row">
            <span class="label">Message</span>
            <div class="message-box">{message}</div>
        </div>
    </div>
    
    <p style="margin: 0; font-size: 14px; text-align: center;">
        <a href="mailto:{email}" style="display: inline-block; background-color: #6366f1; color: #ffffff; text-decoration: none; padding: 12px 24px; border-radius: 6px; font-weight: 600; font-size: 15px;">Reply to Customer</a>
    </p>
    """
    
    footer = """
    <p>This is an automated message from the <strong>XR-DOCK Backend System</strong>.</p>
    <p style="margin-top: 8px;">Please do not reply directly to this email address except using the reply button.</p>
    """
    
    return _get_base_html(
        title="New Contact Request",
        preheader=f"New inquiry from {name}",
        body_content=body,
        footer_content=footer
    )

def get_customer_confirmation_email_html(name: str) -> str:
    body = f"""
    <div class="greeting">Hello {name},</div>
    <p style="margin-top: 0; margin-bottom: 24px; font-size: 15px; line-height: 1.5;">Thank you for approaching us. Our team will contact you shortly.</p>
    <p style="margin-top: 0; font-size: 15px; line-height: 1.5;">Best Regards,<br><strong>The XR-DOCK Team</strong></p>
    """
    
    footer = """
    <p>&copy; 2026 XR-DOCK. All rights reserved.</p>
    <p style="margin-top: 8px;">Powered by <strong>Kuvira Cybernetics</strong></p>
    """
    
    return _get_base_html(
        title="We received your request!",
        preheader="Thank you for contacting XR-DOCK",
        body_content=body,
        footer_content=footer
    )
