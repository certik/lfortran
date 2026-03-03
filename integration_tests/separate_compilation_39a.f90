module separate_compilation_39a
  implicit none
  interface
    module subroutine greet(name, msg)
      character(len=*), intent(in) :: name
      character(len=20), intent(out) :: msg
    end subroutine
  end interface
contains
  pure integer function add(a, b)
    integer, intent(in) :: a, b
    add = a + b
  end function
end module
