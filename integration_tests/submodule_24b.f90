module submodule_24_mod
  implicit none

  type :: string_t
    character(len=:), allocatable :: val
  contains
    procedure :: get_val
  end type

  interface string_t
    module function from_chars(s) result(res)
      character(len=*), intent(in) :: s
      type(string_t) :: res
    end function
  end interface

  interface
    module function get_val(self) result(res)
      class(string_t), intent(in) :: self
      character(len=:), allocatable :: res
    end function
  end interface

end module
