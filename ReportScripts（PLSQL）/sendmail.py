# -*- coding: UTF-8 -*-  
import sys, os, re, urllib, urlparse, time
import pandas as pd
import numpy as np
import smtplib  
import traceback  
from email.mime.text import MIMEText  
from email.mime.multipart import MIMEMultipart


def sendmail(subject,toaddrs,fromaddr,smtpaddr,password):  
    '''
    @subject:邮件主题 
    @msg:邮件内容 
    @toaddrs:收信人的邮箱地址 
    @fromaddr:发信人的邮箱地址 
    @smtpaddr:smtp服务地址，可以在邮箱看，比如163邮箱为smtp.163.com 
    @password:发信人的邮箱密码   
    '''


    result_tab_html = ""
    warning_report_meta = pd.read_table('D:/excel_report/warning_report_meta.txt',sep=',',header=None, names=['report_name','file_name','folder_paths','colname'])
    for row in warning_report_meta.iterrows():
        tmp_reportname = row[1]['report_name']
        tmp_filename = row[1]['file_name']
        tmp_paths = row[1]['folder_paths']
        tmp_file_paths = tmp_paths + tmp_filename
        if os.path.exists(tmp_file_paths):
            xls_file = pd.ExcelFile(tmp_file_paths)
            warning_content = xls_file.parse('Sheet1')
            tmp_counts = len(list(set(warning_content[row[1]['colname'].upper()])))
            
            if tmp_counts > 0:
                is_warning_flag = 'Yes'
            else:
                is_warning_flag = 'No'
            tmp_objects = '<br/>'.join(list(set(warning_content[row[1]['colname'].upper()])))
            
            result_tab_html = result_tab_html + """<tr>   
                                    <td text-align="center">%s</td>
                                    <td>%s</td>
                                    <td>%s</td>
                                    <td>%s</td>
                                    <td>%s</td>
                                </tr> \n""" % (tmp_reportname.decode('utf-8'),tmp_filename,is_warning_flag,tmp_counts,tmp_objects)
        else:
            continue
    mail_msg = MIMEMultipart()  
    if not isinstance(subject,unicode):  
        subject = unicode(subject, 'utf-8') 

    #msg = MIMEMultipart()

    #构造附件1
    #att1 = MIMEText(open('d:\\123.rar', 'rb').read(), 'base64', 'gb2312')
    #att1["Content-Type"] = 'application/octet-stream'
    #att1["Content-Disposition"] = 'attachment; filename="123.doc"'#这里的filename可以任意写，写什么名字，邮件中显示什么名字
    #mail_msg.attach(att1)

    #构造附件2
    #att2 = MIMEText(open('d:\\123.txt', 'rb').read(), 'base64', 'gb2312')
    #att2["Content-Type"] = 'application/octet-stream'
    #att2["Content-Disposition"] = 'attachment; filename="123.txt"'
    #mail_msg.attach(att2)

    mail_msg['Subject'] = subject  
    mail_msg['From'] =fromaddr  
    mail_msg['To'] = ','.join(toaddrs)
    #mail_msg.attach(MIMEText(msg, 'html', 'utf-8'))
    msg = MIMEText("""
                <table color="CCCC33" width="800" border="1" cellspacing="0" cellpadding="5" text-align="center">
                        <tr>
                            <td text-align="center">"""+u'预警报告名'+"""</td>
                            <td text-align="center">"""+u'附件名'+"""</td>
                            <td text-align="center">"""+u'是否预警'+"""</td>
                            <td>"""+u'预警对象数量'+"""</td>
                            <td>"""+u'预警对象名'+"""</td>
                        </tr> \n"""+result_tab_html+"""
                </table>""",'html','utf-8')
    mail_msg.attach(msg)
    try:  
        s = smtplib.SMTP()  
        s.connect(smtpaddr)  #连接smtp服务器  
        s.login(fromaddr,password)  #登录邮箱  
        s.sendmail(fromaddr, toaddrs, mail_msg.as_string()) #发送邮件  
        s.quit()  
    except Exception,e:  
       print "Error: unable to send email"  
       print traceback.format_exc()  
  
if __name__ == '__main__':  
    fromaddr = "wangzhong0502@163.com"  
    smtpaddr = "smtp.163.com"  
    toaddrs = ["37705257@qq.com"]  
    subject = "测试邮件"  
    password = "0502wangzhong"  
    #msg = "测试一下"  
    sendmail(subject,toaddrs,fromaddr,smtpaddr,password)