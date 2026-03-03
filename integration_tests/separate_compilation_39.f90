program separate_compilation_39
  use separate_compilation_39a, only: greet, add
  implicit none
  character(len=20) :: msg
  call greet("world", msg)
  if (trim(msg) /= "Hello, world") error stop
  if (add(1, 2) /= 3) error stop
  print *, "ok"
end program
