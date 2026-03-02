submodule (separate_compilation_37a) separate_compilation_37a_impl
  implicit none
contains
  module function run_cmd(cmd, callback) result(res)
    character(*), intent(in) :: cmd
    procedure(cb_iface), optional :: callback
    integer :: res
    res = len(cmd)
    if (present(callback)) call callback(res)
  end function
end submodule

subroutine my_cb(x)
  integer, intent(in) :: x
  if (x /= 5) error stop
end subroutine

program separate_compilation_37
  use separate_compilation_37a
  implicit none
  integer :: p
  p = run("hello", callback=my_cb)
  if (p /= 5) error stop
  print *, "ok"
end program
