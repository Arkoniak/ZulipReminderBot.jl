using DotEnv
using HTTP
using JSON3

cfg = DotEnv.config()

port = parse(Int, cfg["REMINDER_BOT_PORT"])
host = "127.0.0.1"
# TODO: Change all print to log
println("Starting echo service on $host:$port")
HTTP.serve(host, port) do http
  obj = JSON3.read(HTTP.payload(http))
  println(obj)
  println("")
  println("token: $(obj.token)")

  resp = JSON3.write((content = obj.message.content, ))
  return HTTP.Response(resp)
end
