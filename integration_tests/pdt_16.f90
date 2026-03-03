module pdt_16_mod
  implicit none

  type :: parent_t(k)
    integer, kind :: k = kind(1.0)
    real(k) :: x = 0
  end type

  type, extends(parent_t) :: child_t
    integer :: y = 0
  end type

end module pdt_16_mod

program pdt_16
  use pdt_16_mod
  implicit none

  type(child_t) :: obj
  type(parent_t) :: p

  ! Test 1: parent component access via obj%parent_t
  p%x = 2.5
  obj%parent_t = p
  if (abs(obj%x - 2.5) > 1.0e-5) error stop "parent component assign failed"

  ! Test 2: PDT structure constructor
  obj%parent_t = parent_t(x=1.0)
  if (abs(obj%x - 1.0) > 1.0e-5) error stop "PDT constructor assign failed"

  print *, "PASS"
end program pdt_16
