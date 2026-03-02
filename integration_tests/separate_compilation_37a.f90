! Test: abstract interface defined after its use in procedure() declaration
! inside a generic interface block. The .mod file must preserve the
! callback's parameter types so callers can resolve the generic.
module separate_compilation_37a
  implicit none

  interface run
    module function run_cmd(cmd, callback) result(res)
      character(*), intent(in) :: cmd
      procedure(cb_iface), optional :: callback
      integer :: res
    end function
  end interface

  ! Bug trigger: abstract interface defined AFTER its use in procedure()
  abstract interface
    subroutine cb_iface(x)
      integer, intent(in) :: x
    end subroutine
  end interface

end module
