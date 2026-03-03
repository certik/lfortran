module pdt_15_mod
  implicit none

  type :: parent_t(k)
    integer, kind :: k = kind(1.)
    real(k) :: data_
  end type

  type, extends(parent_t) :: child_t
  contains
    procedure :: get_data => get_data_impl
  end type

contains

  function get_data_impl(self) result(res)
    class(child_t), intent(in) :: self
    real :: res
    res = self%data_
  end function

end module pdt_15_mod

program pdt_15
  use pdt_15_mod
  implicit none

  type(child_t) :: obj

  obj%data_ = 3.14

  if (abs(obj%data_ - 3.14) > 1.0e-5) error stop "data_ value mismatch"
  if (abs(obj%get_data() - 3.14) > 1.0e-5) error stop "get_data() mismatch"

  print *, "PASS"
end program pdt_15
