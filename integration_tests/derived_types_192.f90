! An array section of a character array component of a SEQUENCE type.
! The component is laid out inline as a flat byte blob rather than behind a
! string descriptor, so cutting a section out of it must index the bytes
! directly. Reading the blob as a descriptor used to segfault at run time.
module derived_types_192_mod
  implicit none

  type :: tseq
    sequence
    character(len=3) :: c(4)
    character(len=2) :: d(2,3)
  end type

  type(tseq) :: gsq

end module derived_types_192_mod

program derived_types_192
  use derived_types_192_mod, only: tseq, gsq
  implicit none

  type(tseq) :: sq
  character(len=3) :: x(2)
  integer :: i, j

  sq%c = ["aaa", "bbb", "ccc", "ddd"]
  do j = 1, 3
    do i = 1, 2
      sq%d(i,j) = char(ichar('a') + i - 1)//char(ichar('0') + j - 1)
    end do
  end do

  ! Reading a section
  if (size(sq%c(2:3)) /= 2) error stop
  if (len(sq%c(2:3)) /= 3) error stop
  if (any(sq%c(2:3) /= ["bbb", "ccc"])) error stop
  if (any(sq%c(3:) /= ["ccc", "ddd"])) error stop
  if (any(sq%c(:2) /= ["aaa", "bbb"])) error stop

  ! A section of a rank-2 component, slicing either dimension
  if (any(sq%d(1:2,3) /= ["a2", "b2"])) error stop
  if (any(sq%d(2,2:3) /= ["b1", "b2"])) error stop

  ! Copying a section out
  x = sq%c(2:3)
  if (any(x /= ["bbb", "ccc"])) error stop

  ! Assigning into a section
  sq%c(2:3) = ["xxx", "yyy"]
  if (any(sq%c /= ["aaa", "xxx", "yyy", "ddd"])) error stop

  ! Passing a section as an actual argument
  call take_assumed_shape(sq%c(2:4), 3)
  call take_explicit_shape(sq%c(1:2))

  ! The same component reached through a module variable
  gsq%c = ["ggg", "hhh", "iii", "jjj"]
  if (any(gsq%c(2:3) /= ["hhh", "iii"])) error stop

  print *, "ok"

contains

  subroutine take_assumed_shape(a, n)
    character(len=3), intent(in) :: a(:)
    integer, intent(in) :: n
    if (size(a) /= n) error stop
    if (any(a /= ["xxx", "yyy", "ddd"])) error stop
  end subroutine take_assumed_shape

  subroutine take_explicit_shape(a)
    character(len=3), intent(in) :: a(2)
    if (any(a /= ["aaa", "xxx"])) error stop
  end subroutine take_explicit_shape

end program derived_types_192
