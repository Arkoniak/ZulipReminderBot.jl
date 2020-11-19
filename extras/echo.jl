using HTTP
using JSON3

HTTP.serve("127.0.0.1", 9174) do http
  obj = JSON3.read(HTTP.payload(http))
  println(obj)
  println("")
  println("token: $(obj.token)")

  resp = JSON3.write((content = obj.message.content, ))
  return HTTP.Response(resp)
end
