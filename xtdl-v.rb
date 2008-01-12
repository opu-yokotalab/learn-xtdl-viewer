#!/usr/bin/ruby
require 'cgi'
require 'kconv'
require 'rexml/document'
require 'net/http'

# 入力された内容をチェックする関数
def srcNameCheck(src_name,dir_name)
  err_code = 0
  if src_name.length == 0
    err_code += 1
  end

  if dir_name.length == 0
    err_code += 2
  end
  return err_code
end

# 画面を出力する関数
def view(body_str)
  print "Content-type: text/html\n\n"
  print "<html><head><title>X-TDL Viewer</title>"
  print "<link href=\"learning.css\" rel=\"stylesheet\" type=\"text/css\">"

  print "<link href=\"prettify.css\" type=\"text/css\" rel=\"stylesheet\" /> <script type=\"text/javascript\" src=\"prettify.js\"></script>"

  print "<script type=\"text/javascript\">try{	window.addEventListener(\"load\",prettyPrint,false);}catch(e){	window.attachEvent(\"onload\",prettyPrint);}</script>"

  print "</head><body>"
  print body_str
  print "</body></html>"
  return
end

# 再帰的にノードを探索
def XTDLNodeSearch(dom_obj)
  # 意味要素　配列
  semantic_elem_array = ["explanation","example","illustration","definition","program","algorithm","proof","simulation"]
  
  
  str_buff = ""
  flag = false # 判定フラグ
  if dom_obj.name["xtdl"] ## xtdl要素ならば
    dom_obj.each_element do |elem|
      str_buff += XTDLNodeSearch(elem)
    end
    
  elsif dom_obj.name["section"] ## section 要素ならば
    if dom_obj.attributes["title"] != ""
      str_buff += "<h2>" + dom_obj.attributes["title"].toutf8 + " <span style=\"color:red\">ID : " + dom_obj.attributes["id"].toutf8 + "</span></h2>"
    else
      str_buff += "<br /><br />"
    end
    dom_obj.each_element do |elem|
      str_buff += XTDLNodeSearch(elem)
    end
  else ## 意味要素　ならば
    if dom_obj.attributes["title"] != ""
      str_buff += "<h3>" + dom_obj.attributes["title"].toutf8 + " <span style=\"color:red\">ID : " + dom_obj.attributes["id"].toutf8 + "</span></h3>"
    else
      str_buff += "<br /><br />"
    end
    # 子はHTML？意味要素？
    semantic_elem_array.each do |semantic_elem|
      if dom_obj.elements["./#{semantic_elem}"]
        flag = true
      end
    end
    
    if flag
      # 意味要素の場合
      dom_obj.each_element do |elem|
        str += XTDLNodeSearch(elem)
      end
    else
      # HTMLの場合
      dom_obj.each do |elem|
        str_buff += elem.to_s.toutf8
      end
    end
  end
  
  return str_buff
end

cgi = CGI.new
str_buff = ""

# Form の入力内容
src_name = cgi["src_name"]
dir_name = cgi["dir"]
id = cgi["id"]
err_code = srcNameCheck(src_name,dir_name)

# 入力値のチェック
if err_code > 0 then
  body_str = "<h3>Application Error!!</h3>"
  case err_code
  when 1 then
    body_str += "<p>リソース名を入力してください。<p>"
  when 2 then
    body_str += "<p>作業フォルダ名を入力してください。</p>"
  when 3 then
    body_str += "<p>作業フォルダ名、およびリソース名を入力してください。</p>"
  end
  
  view(body_str.toutf8)
  return
end

# eXist からリソース内容を取得
http = Net::HTTP.new('localhost' , 8080)
req = Net::HTTP::Get.new("/exist/rest/db/work/#{dir_name}/#{src_name}.xml")
res = http.request(req)

# DOM を生成
doc = REXML::Document.new res.body
# idの入力の有無で分岐
if id.length == 0 then
  doc = doc.elements["/xtdl"]
else
  doc = doc.elements["//*[@id='#{id}']"]
end

# DOMチェック
if doc
  # HTML 生成
  body_str = XTDLNodeSearch(doc)
else
  body_str = "<h3>Application Error!!</h3>"
  body_str += "<p>入力した値を確認してください。<p>"
end

# 結果出力
view(body_str.toutf8)
