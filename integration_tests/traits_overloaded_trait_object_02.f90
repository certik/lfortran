! Overloaded generic messages called through a trait object. The two
! `bump` messages are distinguishable by arity. A trait object selects
! the overload statically and dispatches through that slot. The trait
! parameter is unused except to put the messages on the E10 slot surface.
! GFortran does not accept this LFortran extension.
module traits_overloaded_trait_object_02_m
    implicit none
    private
    public :: IMarker, ICounter, Counter

    abstract interface :: IMarker
        integer function tag(self)
            type(itself), pass, intent(in) :: self
        end function tag
    end interface IMarker

    abstract interface :: ICounter
        integer function bump{Trait :: P}(self, x)
            type(itself), pass, intent(in) :: self
            integer, intent(in) :: x
        end function bump
        integer function bump{Trait :: P}(self, x, y)
            type(itself), pass, intent(in) :: self
            integer, intent(in) :: x, y
        end function bump
    end interface ICounter

    type, implements(IMarker) :: Marker
        integer :: n = 1
    contains
        procedure :: tag => marker_tag
    end type Marker

    type, sealed, implements(ICounter) :: Counter
        integer :: bias = 0
    contains
        generic :: bump => bump1, bump2
        procedure :: bump1, bump2
    end type Counter

contains

    integer function marker_tag(self)
        class(Marker), intent(in) :: self
        marker_tag = self%n
    end function marker_tag

    integer function bump1{Trait :: P}(self, x) result(r)
        type(Counter), intent(in) :: self
        integer, intent(in) :: x
        r = x + 1 + self%bias
        if (len(type_name{P}()) < 0) r = 0
    end function bump1

    integer function bump2{Trait :: P}(self, x, y) result(r)
        type(Counter), intent(in) :: self
        integer, intent(in) :: x, y
        r = x + y
    end function bump2

end module traits_overloaded_trait_object_02_m

program traits_overloaded_trait_object_02
    use traits_overloaded_trait_object_02_m
    implicit none
    type(Counter) :: cont
    class(ICounter), allocatable :: view

    if (cont%bump{IMarker}(4) /= 5) error stop 1
    if (cont%bump{IMarker}(4, 6) /= 10) error stop 2
    allocate(Counter :: view)
    if (view%bump{IMarker}(4) /= 5) error stop 3
    if (view%bump{IMarker}(4, 6) /= 10) error stop 4
end program traits_overloaded_trait_object_02
