module gpu_metal_255_m
  implicit none
  type :: network_t
    real, allocatable :: weights(:)
    integer, allocatable :: nodes(:)
  contains
    procedure :: num_inputs
  end type
contains
  elemental integer function num_inputs(self) result(n)
    class(network_t), intent(in) :: self
    n = self%nodes(1)
  end function
end module

program gpu_metal_255
  use gpu_metal_255_m
  implicit none
  type(network_t) :: net
  integer :: i
  real :: a(4)

  allocate(net%nodes(2), source=[2, 1])
  allocate(net%weights(2), source=[1.0, 2.0])

  associate(w => net%weights)
    do concurrent (i = 1:4)
      a(i) = w(1) + net%num_inputs()
    end do
  end associate

  do i = 1, 4
    if (abs(a(i) - 3.0) > 1e-5) error stop
  end do
  print *, "PASS"
end program
